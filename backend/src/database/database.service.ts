import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Pool, PoolClient, type PoolConfig } from "pg";
import { Errors } from "../common/errors";

/** Connection-class failures that are safe to retry once on a fresh socket. */
const CONNECTION_ERROR =
  /terminated unexpectedly|connection terminated|server closed the connection|terminating connection|connection refused|socket hang up|ECONNRESET|ECONNREFUSED|ETIMEDOUT|EPIPE/i;

function isConnectionError(err: unknown): boolean {
  const e = err as { code?: string; message?: string };
  return (
    ["ECONNRESET", "ECONNREFUSED", "ETIMEDOUT", "EPIPE"].includes(e?.code ?? "") ||
    CONNECTION_ERROR.test(e?.message ?? "")
  );
}

/**
 * Thin wrapper over a pg Pool against Neon (PgBouncer transaction mode).
 * All business writes go through `withClient`/`transaction` so connection
 * handling stays uniform.
 *
 * Neon notes:
 * - The compute auto-suspends when idle; pooled sockets can die between
 *   requests. Reads/writes retry ONCE transparently on a fresh connection;
 *   a transaction that already started running user code is never retried
 *   (double-write hazard) — it surfaces as 503 DB_UNAVAILABLE instead.
 * - Migrations must use DATABASE_URL_UNPOOLED (see migrate.ts).
 *
 * RLS note: the app connects as a single service role; per-user visibility
 * is enforced by passing the acting user id into queries (see
 * can_view_batch usage) rather than per-request SET ROLE. This keeps the
 * connection pool simple while preserving the upward-only rule.
 */
@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DatabaseService.name);
  private pool!: Pool;
  private lastProbe?: { at: string; latencyMs: number };

  constructor(private readonly config: ConfigService) {}

  async onModuleInit() {
    const url = this.config.get<string>("DATABASE_URL");
    if (!url) {
      throw new Error("DATABASE_URL is not set");
    }
    this.pool = new Pool(this.poolOptions(url));

    this.pool.on("error", (err) => {
      this.logger.error(`idle client error: ${err.message}`);
    });

    // Startup probe: Neon cold starts can take a few seconds; fail loudly
    // (but not spuriously) if the DB never comes up.
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        const started = Date.now();
        await this.pool.query("SELECT 1");
        this.lastProbe = { at: new Date().toISOString(), latencyMs: Date.now() - started };
        this.logger.log(
          `database probe ok (${this.lastProbe.latencyMs}ms, host=${this.safeHost(url)})`,
        );
        return;
      } catch (err) {
        if (attempt === 3) throw err;
        this.logger.warn(`probe attempt ${attempt} failed, retrying…`);
        await new Promise((r) => setTimeout(r, 2000 * attempt));
      }
    }
  }

  async onModuleDestroy() {
    await this.pool?.end();
  }

  private poolOptions(url: string): PoolConfig {
    const cfg = this.config;
    const sslMode = (cfg.get<string>("DATABASE_SSL") ?? "auto").toLowerCase();

    let effectiveUrl = url;
    if (sslMode === "off") {
      // Local docker etc.: strip any sslmode param so pg doesn't upgrade.
      effectiveUrl = url.replace(/[?&]sslmode=[^&]*/g, (m) => (m.startsWith("?") ? "?" : ""));
    }

    let host = "";
    try {
      host = new URL(effectiveUrl).hostname;
    } catch {
      // keep host empty; ssl decision below falls back to explicit config
    }
    const wantsSsl =
      sslMode === "strict" ||
      (sslMode !== "off" && (/[?&]sslmode=/.test(effectiveUrl) || host.endsWith(".neon.tech")));

    const options: PoolConfig = {
      connectionString: effectiveUrl,
      application_name: "cinnamon-trace-api",
      max: Number(cfg.get("PG_POOL_MAX") ?? 10),
      idleTimeoutMillis: Number(cfg.get("PG_IDLE_TIMEOUT_MS") ?? 30_000),
      // Cold Neon compute can take seconds to accept sockets, and a burst of
      // concurrent first-requests opens several TLS connections at once —
      // give the handshake room before giving up.
      connectionTimeoutMillis: Number(cfg.get("PG_CONNECT_TIMEOUT_MS") ?? 15_000),
      keepAlive: true,
      keepAliveInitialDelayMillis: 10_000,
    };
    if (wantsSsl) {
      // Neon chains to public CAs — real certificate verification works, and
      // being explicit silences the pg sslmode=require→verify-full warning.
      options.ssl = { rejectUnauthorized: true };
    }
    return options;
  }

  private safeHost(url: string): string {
    try {
      return new URL(url).hostname;
    } catch {
      return "unknown";
    }
  }

  /** Pool + probe snapshot for /health. */
  stats() {
    return {
      pool: {
        total: this.pool?.totalCount ?? 0,
        idle: this.pool?.idleCount ?? 0,
        waiting: this.pool?.waitingCount ?? 0,
      },
      lastProbe: this.lastProbe ?? null,
    };
  }

  async query<T = Record<string, unknown>>(
    text: string,
    params: unknown[] = [],
  ): Promise<T[]> {
    try {
      return await this.run(text, params);
    } catch (err) {
      if (!isConnectionError(err)) throw err;
      this.logger.warn(`connection dropped, retrying once: ${(err as Error).message}`);
      await new Promise((r) => setTimeout(r, 250));
      return this.run(text, params);
    }
  }

  async queryOne<T = Record<string, unknown>>(
    text: string,
    params: unknown[] = [],
  ): Promise<T | null> {
    const rows = await this.query<T>(text, params);
    return rows[0] ?? null;
  }

  async withClient<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      return await fn(client);
    } finally {
      client.release();
    }
  }

  async transaction<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
    // Phase 1 (protected): acquiring a connection and BEGIN may retry once —
    // no user code has run, so a retry cannot duplicate writes.
    let client: PoolClient | null = null;
    for (let attempt = 0; ; attempt++) {
      try {
        client = await this.pool.connect();
        await client.query("BEGIN");
        break;
      } catch (err) {
        client?.release();
        client = null;
        if (attempt === 0 && isConnectionError(err)) {
          this.logger.warn(`transaction begin dropped, retrying once: ${(err as Error).message}`);
          await new Promise((r) => setTimeout(r, 250));
          continue;
        }
        throw this.dbUnavailable(err);
      }
    }

    // Phase 2 (unprotected): user code + COMMIT. Any connection failure here
    // is surfaced as 503 — the caller retries at the business level.
    try {
      const result = await fn(client);
      await client.query("COMMIT");
      client.release();
      return result;
    } catch (err) {
      try {
        await client.query("ROLLBACK");
      } catch {
        // connection already dead — release below regardless
      }
      client.release();
      if (isConnectionError(err)) throw this.dbUnavailable(err);
      throw err;
    }
  }

  private dbUnavailable(err: unknown): Error {
    const e = err as { code?: string };
    if (e?.code === "23505" || (err instanceof Error && !isConnectionError(err))) {
      return err as Error; // domain/business errors pass through untouched
    }
    this.logger.error(`database unavailable: ${(err as Error).message}`);
    return Errors.serviceUnavailable("DB_UNAVAILABLE", "Database is temporarily unavailable");
  }

  private async run<T = Record<string, unknown>>(
    text: string,
    params: unknown[],
  ): Promise<T[]> {
    const result = await this.pool.query(text, params);
    return result.rows as T[];
  }
}

import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Pool, PoolClient } from "pg";

/**
 * Thin wrapper over a pg Pool. All business writes go through
 * `withClient`/`transaction` so connection handling stays uniform.
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

  constructor(private readonly config: ConfigService) {}

  async onModuleInit() {
    const url = this.config.get<string>("DATABASE_URL");
    if (!url) {
      throw new Error("DATABASE_URL is not set");
    }
    this.pool = new Pool({ connectionString: url, max: 10 });
    this.pool.on("error", (err) => {
      this.logger.error(`idle client error: ${err.message}`);
    });
  }

  async onModuleDestroy() {
    await this.pool?.end();
  }

  async query<T = Record<string, unknown>>(
    text: string,
    params: unknown[] = [],
  ): Promise<T[]> {
    const result = await this.pool.query(text, params);
    return result.rows as T[];
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
    return this.withClient(async (client) => {
      await client.query("BEGIN");
      try {
        const result = await fn(client);
        await client.query("COMMIT");
        return result;
      } catch (err) {
        await client.query("ROLLBACK");
        throw err;
      }
    });
  }
}

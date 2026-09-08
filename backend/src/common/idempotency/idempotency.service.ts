import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Cron } from "@nestjs/schedule";
import { createHash } from "node:crypto";
import { DatabaseService } from "../../database/database.service";
import { canonicalJson } from "../../integrity/hash-chain";

export type ClaimState =
  | { state: "claimed" } // we own the claim; execute the handler
  | { state: "in_progress" }
  | { state: "completed"; requestHash: string; responseBody: unknown };

const TAKEOVER_AFTER_MS = 60_000;

/**
 * Server-side idempotency for mutating endpoints (api-spec §Conventions).
 * Claims are scoped to (key, endpoint, user_id). Only 2xx outcomes are ever
 * stored — a stored failure would make a retryable condition permanent.
 */
@Injectable()
export class IdempotencyService {
  private readonly logger = new Logger(IdempotencyService.name);
  private readonly ttlHours: number;

  constructor(
    private readonly db: DatabaseService,
    config: ConfigService,
  ) {
    this.ttlHours = Number(config.get("IDEMPOTENCY_TTL_HOURS") ?? 72);
  }

  /** Canonical-JSON hash: key order / whitespace drift can't fake a mismatch. */
  static requestHash(body: unknown): string {
    return createHash("sha256").update(canonicalJson(body ?? null)).digest("hex");
  }

  /**
   * Atomically claim (key, endpoint, userId). Uses INSERT .. ON CONFLICT DO
   * NOTHING for the fast path; on conflict it either replays a completed
   * outcome or reports in-progress / takes over a stale in-flight claim.
   */
  async claim(
    key: string,
    endpoint: string,
    userId: string,
    requestHash: string,
  ): Promise<ClaimState> {
    const inserted = await this.db.queryOne<{
      request_hash: string;
      status_code: number | null;
      response_body: unknown;
    }>(
      `INSERT INTO idempotency_keys (key, endpoint, user_id, request_hash)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (key, endpoint, user_id) DO NOTHING
       RETURNING request_hash, status_code, response_body`,
      [key, endpoint, userId, requestHash],
    );
    if (inserted) return { state: "claimed" };

    const existing = await this.db.queryOne<{
      request_hash: string;
      status_code: number | null;
      response_body: unknown;
      locked_at: Date;
    }>(
      "SELECT request_hash, status_code, response_body, locked_at FROM idempotency_keys WHERE key = $1 AND endpoint = $2 AND user_id = $3",
      [key, endpoint, userId],
    );
    if (!existing) return { state: "claimed" }; // raced delete (failed run)

    if (existing.status_code !== null && existing.response_body !== null) {
      return {
        state: "completed",
        requestHash: existing.request_hash,
        responseBody: existing.response_body,
      };
    }

    // In flight by another request — unless the lock is stale (crashed mid-
    // flight), then take it over.
    const staleCut = new Date(Date.now() - TAKEOVER_AFTER_MS);
    if (new Date(existing.locked_at) < staleCut) {
      const taken = await this.db.queryOne<{ key: string }>(
        `UPDATE idempotency_keys SET locked_at = now(), request_hash = $4
         WHERE key = $1 AND endpoint = $2 AND user_id = $3 AND locked_at < $5
         RETURNING key`,
        [key, endpoint, userId, requestHash, staleCut],
      );
      if (taken) return { state: "claimed" };
    }
    return { state: "in_progress" };
  }

  /**
   * Store the outcome of a successful (2xx) execution. The recorded status
   * mirrors the route default (201 for POST, 200 otherwise) — replays apply
   * the same route default automatically.
   */
  async complete(
    key: string,
    endpoint: string,
    userId: string,
    method: "POST" | "PATCH" | "PUT",
    responseBody: unknown,
  ): Promise<void> {
    await this.db.query(
      `UPDATE idempotency_keys
       SET status_code = $4, response_body = $5::jsonb
       WHERE key = $1 AND endpoint = $2 AND user_id = $3`,
      [key, endpoint, userId, method === "POST" ? 201 : 200, JSON.stringify(responseBody ?? null)],
    );
  }

  /** Drop the claim after a failed execution so the same key can be retried. */
  async release(key: string, endpoint: string, userId: string): Promise<void> {
    await this.db.query(
      "DELETE FROM idempotency_keys WHERE key = $1 AND endpoint = $2 AND user_id = $3",
      [key, endpoint, userId],
    );
  }

  /** Nightly cleanup of expired keys (03:17 — off the hour, off the anchor job). */
  @Cron("17 3 * * *")
  async purgeExpired(): Promise<number> {
    const result = await this.db.query<{ n: string }>(
      `WITH del AS (
         DELETE FROM idempotency_keys WHERE created_at < now() - ($1 || ' hours')::interval
         RETURNING 1
       ) SELECT count(*)::text AS n FROM del`,
      [String(this.ttlHours)],
    );
    const n = Number(result[0]?.n ?? 0);
    if (n > 0) this.logger.log(`purged ${n} expired idempotency keys`);
    return n;
  }
}

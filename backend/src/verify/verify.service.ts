import { Injectable } from "@nestjs/common";
import { BatchesService } from "../batches/batches.service";
import { DatabaseService } from "../database/database.service";
import { computeVerdict, verifyChain, type StoredEvent } from "../integrity";

export interface VerifyResult {
  batch_no: string;
  verdict: "AUTHENTIC" | "TAMPERED" | "PENDING";
  anchors: Array<{
    network: string;
    tx_hash: string | null;
    anchored_at: string;
    status: string;
  }>;
  origin: Record<string, unknown> | null;
  chain: Array<{
    event_type: string;
    actor_role: string;
    actor_name: string;
    summary: string;
    at: string;
    event_hash: string;
    verified: boolean;
  }>;
}

/**
 * Public verification — no auth. Recomputes the event hash chain from stored
 * rows and compares against the anchored Merkle roots to produce a verdict.
 */
@Injectable()
export class VerifyService {
  constructor(
    private readonly db: DatabaseService,
    private readonly batches: BatchesService,
  ) {}

  async verify(batchNo: string): Promise<VerifyResult | null> {
    const chainData = await this.batches.publicChain(batchNo);
    if (!chainData) return null;

    const batch = await this.batches.findRowByNo(batchNo);
    if (!batch) return null;

    // Recompute the hash chain from raw event rows.
    const events = await this.db.query<Record<string, unknown>>(
      `SELECT batch_id, event_type, actor_user_id, actor_role, payload,
              parent_event_hash, event_hash, created_at
       FROM batch_events WHERE batch_id = $1
       ORDER BY created_at ASC, id ASC`,
      [batch.id],
    );

    const stored: StoredEvent[] = events.map((e) => ({
      batchId: e.batch_id as string,
      eventType: e.event_type as string,
      actorUserId: e.actor_user_id as string,
      actorRole: e.actor_role as string,
      payload: e.payload,
      parentEventHash: (e.parent_event_hash as string | null) ?? null,
      // node-postgres returns timestamptz as Date objects; the hash was
      // computed over the original ISO-8601 string, so normalize back.
      occurredAt: new Date(e.created_at as string).toISOString(),
      eventHash: e.event_hash as string,
    }));
    const chainResult = verifyChain(stored);
    const chainValid = chainResult.valid;

    // Anchor status: an anchor "covers" this batch once its events carry
    // anchored_at. The verdict requires ALL events anchored; partial
    // anchoring stays PENDING rather than over-claiming AUTHENTIC.
    const counts = await this.db.queryOne<{ total: string; anchored: string }>(
      `SELECT count(*)::text AS total,
              count(anchored_at)::text AS anchored
       FROM batch_events WHERE batch_id = $1`,
      [batch.id],
    );
    const total = Number(counts?.total ?? 0);
    const anchoredCount = Number(counts?.anchored ?? 0);
    const anchorConfirmed = total > 0 && anchoredCount === total;

    // Only list anchors that could actually cover this batch (created after
    // its first event). A global "last 5" list would show unrelated evidence.
    const firstEventRow = await this.db.queryOne<{ first_at: string }>(
      "SELECT min(created_at)::text AS first_at FROM batch_events WHERE batch_id = $1",
      [batch.id],
    );
    const anchors = firstEventRow?.first_at
      ? await this.db.query<{
          network: string;
          tx_hash: string | null;
          anchored_at: string;
          status: string;
        }>(
          `SELECT network, tx_hash, anchored_at, status FROM chain_anchors
           WHERE anchored_at >= $1::timestamptz
           ORDER BY anchored_at DESC LIMIT 5`,
          [firstEventRow.first_at],
        )
      : [];

    const verdict = computeVerdict({ chainValid, anchorConfirmed });

    return {
      batch_no: batch.batch_no,
      verdict,
      anchors,
      origin: chainData.origin,
      chain: chainData.events.map((e) => ({
        ...e,
        verified: chainValid,
      })),
    };
  }
}

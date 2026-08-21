import { Injectable } from "@nestjs/common";
import { PoolClient } from "pg";
import { DatabaseService } from "../database/database.service";
import { computeEventHash } from "../integrity/hash-chain";
import { uuidv7 } from "../common/uuid";

export type EventType =
  | "CREATED"
  | "TRANSFERRED"
  | "PROCESSED"
  | "MERGED_IN"
  | "EXPORTED"
  | "ANCHORED";

export interface AppendEventInput {
  batchId: string;
  eventType: EventType;
  actorUserId: string;
  actorRole: string;
  payload: Record<string, unknown>;
  fromUserId?: string;
  toUserId?: string;
  transferKind?: "SALE" | "HANDOFF";
}

export interface EventRow {
  id: string;
  batch_id: string;
  event_type: EventType;
  actor_user_id: string;
  actor_role: string;
  from_user_id: string | null;
  to_user_id: string | null;
  transfer_kind: string | null;
  payload: Record<string, unknown>;
  parent_event_hash: string | null;
  event_hash: string;
  anchored_at: string | null;
  created_at: string;
}

/**
 * Append-only, hash-chained event ledger. Every event's hash commits to its
 * parent's hash (the batch's current chain head), so the chain is
 * tamper-evident. Writes MUST happen inside a transaction that also holds the
 * batch row lock, to serialize chain-head updates per batch.
 */
@Injectable()
export class LedgerService {
  constructor(private readonly db: DatabaseService) {}

  /**
   * Append an event to a batch's chain. Must be called within a transaction
   * that has already locked the batch row (SELECT ... FOR UPDATE) so the
   * chain head cannot advance concurrently.
   */
  async appendEvent(client: PoolClient, input: AppendEventInput): Promise<EventRow> {
    const head = await client.query<{ chain_head_hash: string | null }>(
      "SELECT chain_head_hash FROM batches WHERE id = $1 FOR UPDATE",
      [input.batchId],
    );
    if (head.rowCount === 0) {
      throw new Error(`LedgerService: batch ${input.batchId} not found`);
    }
    const parentHash = head.rows[0]?.chain_head_hash ?? null;
    const occurredAt = new Date().toISOString();

    const eventHash = computeEventHash({
      batchId: input.batchId,
      eventType: input.eventType,
      actorUserId: input.actorUserId,
      actorRole: input.actorRole,
      payload: input.payload,
      parentEventHash: parentHash,
      occurredAt,
    });

    const eventId = uuidv7();
    const result = await client.query<EventRow>(
      `INSERT INTO batch_events
         (id, batch_id, event_type, actor_user_id, actor_role,
          from_user_id, to_user_id, transfer_kind, payload,
          parent_event_hash, event_hash, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
       RETURNING *`,
      [
        eventId,
        input.batchId,
        input.eventType,
        input.actorUserId,
        input.actorRole,
        input.fromUserId ?? null,
        input.toUserId ?? null,
        input.transferKind ?? null,
        JSON.stringify(input.payload),
        parentHash,
        eventHash,
        occurredAt,
      ],
    );

    await client.query("UPDATE batches SET chain_head_hash = $1 WHERE id = $2", [
      eventHash,
      input.batchId,
    ]);

    return result.rows[0];
  }

  /** Events for one batch, oldest first. */
  async eventsForBatch(batchId: string): Promise<EventRow[]> {
    return this.db.query<EventRow>(
      "SELECT * FROM batch_events WHERE batch_id = $1 ORDER BY created_at ASC, id ASC",
      [batchId],
    );
  }
}

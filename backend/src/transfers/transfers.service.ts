import { Injectable } from "@nestjs/common";
import { Errors } from "../common/errors";
import { DatabaseService } from "../database/database.service";
import { LedgerService } from "../batches/ledger.service";
import { RecipientsQuery, TransferDto } from "./dto";

/**
 * Transfer matrix (PLAN §3.4). Key = sender role, value = allowed recipient
 * roles. Collector can hand to anyone except Farmer; Exporter is terminal.
 */
export const TRANSFER_MATRIX: Record<string, string[]> = {
  FARMER: ["COLLECTOR", "PROCESSOR_L1"],
  COLLECTOR: ["COLLECTOR", "PROCESSOR_L1", "PROCESSOR_L2", "EXPORTER"],
  PROCESSOR_L1: ["COLLECTOR", "PROCESSOR_L2", "EXPORTER"],
  PROCESSOR_L2: ["COLLECTOR", "EXPORTER"],
  EXPORTER: [],
};

const TRANSFERABLE_STATUSES = ["HARVESTED", "RECEIVED", "PROCESSED"];

interface BatchLite {
  id: string;
  batch_no: string;
  status: string;
  weight_kg: string;
  current_holder_id: string | null;
  current_holder_role: string | null;
  root_batch_no: string;
}

@Injectable()
export class TransfersService {
  constructor(
    private readonly db: DatabaseService,
    private readonly ledger: LedgerService,
  ) {}

  /** Recipient lookup filtered to roles the sender may transfer to. */
  async recipients(userId: string, query: RecipientsQuery) {
    const senderRoles = await this.getRoles(userId);
    const allowed = new Set<string>();
    for (const role of senderRoles) {
      for (const target of TRANSFER_MATRIX[role] ?? []) allowed.add(target);
    }
    if (allowed.size === 0) return [];

    const q = query.q ?? "";
    const rows = await this.db.query<{
      id: string;
      name: string;
      mobile: string;
      role: string;
    }>(
      `SELECT DISTINCT u.id, u.name, u.mobile, ur.role
       FROM users u
       JOIN user_roles ur ON ur.user_id = u.id
       WHERE u.id <> $1
         AND ur.role = ANY($2::role_code[])
         AND ($3 = '' OR u.mobile ILIKE $4 OR u.name ILIKE $4)
       ORDER BY u.name
       LIMIT 20`,
      [userId, Array.from(allowed), q, `%${q}%`],
    );
    return rows.map((r) => ({ id: r.id, name: r.name, mobile: r.mobile, role: r.role }));
  }

  async transfer(userId: string, batchId: string, dto: TransferDto) {
    return this.db.transaction(async (client) => {
      const batch = await this.getBatchForUpdate(client, batchId);
      if (!batch) throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");
      if (batch.current_holder_id !== userId) {
        throw Errors.forbidden("NOT_HOLDER", "You do not hold this batch");
      }
      if (!TRANSFERABLE_STATUSES.includes(batch.status)) {
        throw Errors.conflict(
          "NOT_TRANSFERABLE",
          `Batch in status ${batch.status} cannot be transferred`,
        );
      }

      const senderRole = batch.current_holder_role ?? (await this.primaryRole(client, userId));
      const recipientRoles = await this.getRoles(dto.to_user_id);
      const allowed = TRANSFER_MATRIX[senderRole] ?? [];
      const validTarget = recipientRoles.find((r) => allowed.includes(r));
      if (!validTarget) {
        throw Errors.forbidden(
          "TRANSFER_NOT_ALLOWED",
          `A ${senderRole} cannot transfer to this recipient's roles`,
        );
      }
      if (dto.to_user_id === userId) {
        throw Errors.badRequest("SELF_TRANSFER", "Cannot transfer to yourself");
      }

      await client.query(
        `UPDATE batches
         SET status = 'IN_TRANSIT', current_holder_id = $1, current_holder_role = $2
         WHERE id = $3`,
        [dto.to_user_id, validTarget, batchId],
      );

      await this.ledger.appendEvent(client, {
        batchId,
        eventType: "TRANSFERRED",
        actorUserId: userId,
        actorRole: senderRole,
        fromUserId: userId,
        toUserId: dto.to_user_id,
        transferKind: dto.transfer_kind,
        payload: {
          kind: dto.transfer_kind,
          price_lkr: dto.price_lkr ?? null,
          notes: dto.notes ?? null,
          weight_kg: Number(batch.weight_kg),
        },
      });

      // Visibility for the recipient (trigger also maintains this).
      await client.query(
        `INSERT INTO batch_actors (batch_id, user_id, role)
         VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
        [batchId, dto.to_user_id, validTarget],
      );

      return {
        batch_id: batchId,
        batch_no: batch.batch_no,
        status: "IN_TRANSIT",
        to_user_id: dto.to_user_id,
        transfer_kind: dto.transfer_kind,
      };
    });
  }

  /** Incoming transfers for the current user. */
  async inbox(userId: string) {
    const rows = await this.db.query<{
      batch_id: string;
      batch_no: string;
      weight_kg: string;
      status: string;
      from_name: string;
      from_role: string;
      transfer_kind: string;
      transferred_at: string;
    }>(
      `SELECT b.id AS batch_id, b.batch_no, b.weight_kg, b.status,
              u.name AS from_name, e.actor_role AS from_role,
              COALESCE(e.transfer_kind, 'HANDOFF') AS transfer_kind,
              e.created_at AS transferred_at
       FROM batches b
       JOIN batch_events e ON e.batch_id = b.id AND e.event_type = 'TRANSFERRED'
       JOIN users u ON u.id = e.actor_user_id
       WHERE b.current_holder_id = $1 AND b.status = 'IN_TRANSIT'
         AND e.id = (SELECT e2.id FROM batch_events e2
                     WHERE e2.batch_id = b.id AND e2.event_type = 'TRANSFERRED'
                     ORDER BY e2.created_at DESC, e2.id DESC LIMIT 1)
       ORDER BY e.created_at DESC`,
      [userId],
    );
    return rows.map((r) => ({
      batch_id: r.batch_id,
      batch_no: r.batch_no,
      weight_kg: Number(r.weight_kg),
      from_name: r.from_name,
      from_role: r.from_role,
      transfer_kind: r.transfer_kind,
      transferred_at: r.transferred_at,
    }));
  }

  async accept(userId: string, batchId: string) {
    return this.db.transaction(async (client) => {
      const batch = await this.getBatchForUpdate(client, batchId);
      if (!batch) throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");
      if (batch.current_holder_id !== userId || batch.status !== "IN_TRANSIT") {
        throw Errors.conflict("NOT_PENDING", "No pending transfer for this batch");
      }

      const recipientRole =
        batch.current_holder_role ?? (await this.primaryRole(client, userId));

      await client.query(
        "UPDATE batches SET status = 'RECEIVED' WHERE id = $1",
        [batchId],
      );

      await this.ledger.appendEvent(client, {
        batchId,
        eventType: "PROCESSED",
        actorUserId: userId,
        actorRole: recipientRole,
        payload: { action: "RECEIVED", weight_kg: Number(batch.weight_kg) },
      });

      return { batch_id: batchId, batch_no: batch.batch_no, status: "RECEIVED" };
    });
  }

  private async getBatchForUpdate(
    client: import("pg").PoolClient,
    batchId: string,
  ): Promise<BatchLite | null> {
    const result = await client.query<BatchLite>(
      "SELECT * FROM batches WHERE id = $1 FOR UPDATE",
      [batchId],
    );
    return result.rows[0] ?? null;
  }

  private async getRoles(userId: string): Promise<string[]> {
    const rows = await this.db.query<{ role: string }>(
      "SELECT role FROM user_roles WHERE user_id = $1",
      [userId],
    );
    return rows.map((r) => r.role);
  }

  private async primaryRole(
    client: import("pg").PoolClient,
    userId: string,
  ): Promise<string> {
    const result = await client.query<{ role: string }>(
      "SELECT role FROM user_roles WHERE user_id = $1 ORDER BY role LIMIT 1",
      [userId],
    );
    return result.rows[0]?.role ?? "FARMER";
  }
}

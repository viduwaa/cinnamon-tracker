import { Injectable } from "@nestjs/common";
import { Errors } from "../common/errors";
import { DatabaseService } from "../database/database.service";
import { CreateBatchDto, ListBatchesQuery } from "./dto";
import { LedgerService } from "./ledger.service";

interface BatchRow {
  id: string;
  batch_no: string;
  farm_id: string | null;
  harvest_type: string | null;
  harvest_date: string | null;
  tree_count: number | null;
  weight_kg: string;
  status: string;
  current_holder_id: string | null;
  current_holder_role: string | null;
  root_batch_no: string;
  stage_suffix: string;
  parents: unknown;
  chain_head_hash: string | null;
  created_by: string;
  created_at: string;
}

@Injectable()
export class BatchesService {
  constructor(
    private readonly db: DatabaseService,
    private readonly ledger: LedgerService,
  ) {}

  /**
   * Create a root harvest batch (farmer only). The batch number is generated
   * client-side for offline support; the server enforces format + uniqueness.
   * Collision → 409 BATCH_NO_TAKEN so the client can regenerate with the
   * next sequence.
   */
  async create(userId: string, dto: CreateBatchDto) {
    const farm = await this.db.queryOne<{ id: string; owner_user_id: string }>(
      "SELECT id, owner_user_id FROM farms WHERE id = $1",
      [dto.farm_id],
    );
    if (!farm || farm.owner_user_id !== userId) {
      throw Errors.forbidden("FARM_NOT_OWNED", "Farm does not belong to you");
    }

    const isFarmer = await this.hasRole(userId, "FARMER");
    if (!isFarmer) {
      throw Errors.forbidden("ROLE_REQUIRED", "Only farmers can create harvest batches");
    }

    const harvestDate = dto.harvest_date.slice(0, 10);
    if (harvestDate > new Date().toISOString().slice(0, 10)) {
      throw Errors.badRequest("FUTURE_DATE", "Harvest date cannot be in the future");
    }

    await this.db.transaction(async (client) => {
      const dup = await client.query("SELECT 1 FROM batches WHERE batch_no = $1", [
        dto.batch_no,
      ]);
      if (dup.rowCount && dup.rowCount > 0) {
        throw Errors.conflict("BATCH_NO_TAKEN", "Batch number already exists", {
          batch_no: dto.batch_no,
        });
      }

      await client.query(
        `INSERT INTO batches
           (id, batch_no, farm_id, harvest_type, harvest_date, tree_count,
            weight_kg, status, current_holder_id, current_holder_role,
            root_batch_no, stage_suffix, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 'HARVESTED', $8, 'FARMER', $9, '', $10)`,
        [
          dto.id,
          dto.batch_no,
          dto.farm_id,
          dto.harvest_type,
          harvestDate,
          dto.tree_count ?? null,
          dto.weight_kg,
          userId,
          dto.batch_no,
          userId,
        ],
      );

      await this.ledger.appendEvent(client, {
        batchId: dto.id,
        eventType: "CREATED",
        actorUserId: userId,
        actorRole: "FARMER",
        payload: {
          batch_no: dto.batch_no,
          harvest_type: dto.harvest_type,
          harvest_date: harvestDate,
          tree_count: dto.tree_count ?? null,
          weight_kg: dto.weight_kg,
        },
      });

      // Visibility cache row for the creator (trigger also adds it, but the
      // trigger runs on batch_events insert; keep both for safety).
      await client.query(
        `INSERT INTO batch_actors (batch_id, user_id, role)
         VALUES ($1, $2, 'FARMER') ON CONFLICT DO NOTHING`,
        [dto.id, userId],
      );
    });

    // Read after commit — get() uses the pool, which cannot see uncommitted
    // rows from the transaction above.
    return this.get(userId, dto.id);
  }

  /** Batches visible to the user: held, acted on, or grown on their farms. */
  async listMine(userId: string, query: ListBatchesQuery) {
    const limit = query.limit ?? 20;
    const offset = query.offset ?? 0;
    const conditions: string[] = [
      `(b.current_holder_id = $1
        OR EXISTS (SELECT 1 FROM batch_actors ba WHERE ba.batch_id = b.id AND ba.user_id = $1)
        OR EXISTS (SELECT 1 FROM farms f WHERE f.id = b.farm_id AND f.owner_user_id = $1))`,
    ];
    const params: unknown[] = [userId];
    let i = 2;

    if (query.status) {
      conditions.push(`b.status = $${i++}`);
      params.push(query.status);
    }
    if (query.q) {
      conditions.push(`b.batch_no ILIKE $${i++}`);
      params.push(`%${query.q}%`);
    }

    params.push(limit, offset);
    const rows = await this.db.query<BatchRow>(
      `SELECT b.* FROM batches b
       WHERE ${conditions.join(" AND ")}
       ORDER BY b.created_at DESC
       LIMIT $${i} OFFSET $${i + 1}`,
      params,
    );
    const countRow = await this.db.queryOne<{ n: string }>(
      `SELECT count(*)::text AS n FROM batches b WHERE ${conditions.join(" AND ")}`,
      params.slice(0, params.length - 2),
    );

    return {
      data: rows.map((r) => this.toSummary(r)),
      meta: { total: Number(countRow?.n ?? 0), limit, offset },
    };
  }

  async get(userId: string, batchId: string) {
    const row = await this.db.queryOne<BatchRow>(
      "SELECT * FROM batches WHERE id = $1",
      [batchId],
    );
    if (!row) throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");
    if (!(await this.canView(userId, batchId))) {
      // Upward-only + privacy: indistinguishable from not found.
      throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");
    }
    return this.toDetail(row);
  }

  async getByNo(userId: string, batchNo: string) {
    const row = await this.db.queryOne<BatchRow>(
      "SELECT * FROM batches WHERE batch_no = $1",
      [batchNo],
    );
    if (!row) throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");
    if (!(await this.canView(userId, row.id))) {
      throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");
    }
    return this.toDetail(row);
  }

  /** Upward chain: this batch's events with actor names + origin farm. */
  async chain(userId: string, batchId: string) {
    await this.get(userId, batchId); // visibility check
    return this.buildChain(batchId);
  }

  /** Public chain for the verify portal — no visibility restriction. */
  async publicChain(batchNo: string) {
    const row = await this.db.queryOne<BatchRow>(
      "SELECT * FROM batches WHERE batch_no = $1",
      [batchNo],
    );
    if (!row) return null;
    return this.buildChain(row.id);
  }

  async findRowByNo(batchNo: string): Promise<BatchRow | null> {
    return this.db.queryOne<BatchRow>("SELECT * FROM batches WHERE batch_no = $1", [
      batchNo,
    ]);
  }

  async canView(userId: string, batchId: string): Promise<boolean> {
    const row = await this.db.queryOne<{ ok: boolean }>(
      `SELECT (
         EXISTS (SELECT 1 FROM batch_actors ba WHERE ba.batch_id = $1 AND ba.user_id = $2)
         OR EXISTS (SELECT 1 FROM batches b JOIN farms f ON f.id = b.farm_id
                    WHERE b.id = $1 AND f.owner_user_id = $2)
       ) AS ok`,
      [batchId, userId],
    );
    return Boolean(row?.ok);
  }

  private async buildChain(batchId: string) {
    const events = await this.db.query<
      Record<string, unknown> & {
        event_type: string;
        actor_role: string;
        actor_name: string;
        payload: Record<string, unknown>;
        event_hash: string;
        anchored_at: string | null;
        created_at: string;
      }
    >(
      `SELECT e.event_type, e.actor_role, u.name AS actor_name, e.payload,
              e.event_hash, e.anchored_at, e.created_at
       FROM batch_events e
       JOIN users u ON u.id = e.actor_user_id
       WHERE e.batch_id = $1
       ORDER BY e.created_at ASC, e.id ASC`,
      [batchId],
    );

    const batch = await this.db.queryOne<BatchRow>(
      "SELECT * FROM batches WHERE id = $1",
      [batchId],
    );
    let origin: Record<string, unknown> | null = null;
    if (batch?.farm_id) {
      const farm = await this.db.queryOne<{
        name: string;
        area_code: string;
        lat: string | null;
        lng: string | null;
        location_public_level: string;
      }>("SELECT name, area_code, lat, lng, location_public_level FROM farms WHERE id = $1", [
        batch.farm_id,
      ]);
      if (farm) {
        origin = {
          farm_name: farm.name,
          area_code: farm.area_code,
          // Respect the farmer's privacy choice on public surfaces.
          location:
            farm.location_public_level === "EXACT" && farm.lat !== null
              ? { lat: Number(farm.lat), lng: Number(farm.lng) }
              : farm.area_code,
        };
      }
    }

    return {
      batch_no: batch?.batch_no,
      root_batch_no: batch?.root_batch_no,
      origin,
      events: events.map((e) => ({
        event_type: e.event_type,
        actor_role: e.actor_role,
        actor_name: e.actor_name,
        summary: this.summarize(e.event_type, e.payload),
        at: e.created_at,
        event_hash: e.event_hash,
        anchored: e.anchored_at !== null,
      })),
    };
  }

  private summarize(eventType: string, payload: Record<string, unknown>): string {
    switch (eventType) {
      case "CREATED":
        return `Harvested ${payload.weight_kg ?? "?"} kg (${payload.harvest_type === "T" ? "trees" : "quills"})`;
      case "TRANSFERRED":
        return payload.kind === "SALE" ? "Sold" : "Handed over";
      case "PROCESSED":
        if (payload.action === "RECEIVED") return "Received";
        return `Processed → ${payload.output_weight_kg ?? "?"} kg`;
      case "MERGED_IN":
        return "Merged into export lot";
      case "EXPORTED":
        return "Exported";
      default:
        return eventType;
    }
  }

  private toSummary(row: BatchRow) {
    return {
      id: row.id,
      batch_no: row.batch_no,
      status: row.status,
      harvest_type: row.harvest_type,
      harvest_date: row.harvest_date,
      weight_kg: Number(row.weight_kg),
      root_batch_no: row.root_batch_no,
      stage_suffix: row.stage_suffix,
      created_at: row.created_at,
    };
  }

  private async toDetail(row: BatchRow) {
    const chain = await this.buildChain(row.id);
    const holder = row.current_holder_id
      ? await this.db.queryOne<{ name: string }>(
          "SELECT name FROM users WHERE id = $1",
          [row.current_holder_id],
        )
      : null;
    return {
      ...this.toSummary(row),
      tree_count: row.tree_count,
      current_holder: holder
        ? { name: holder.name, role: row.current_holder_role }
        : null,
      chain: chain.events,
      origin: chain.origin,
      verification: {
        status: row.chain_head_hash ? "HASHED" : "PENDING",
        chain_head_hash: row.chain_head_hash,
      },
    };
  }

  private async hasRole(userId: string, role: string): Promise<boolean> {
    const row = await this.db.queryOne(
      "SELECT 1 FROM user_roles WHERE user_id = $1 AND role = $2",
      [userId, role],
    );
    return row !== null;
  }
}

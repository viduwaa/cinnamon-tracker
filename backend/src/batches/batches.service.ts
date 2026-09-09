import { Injectable } from "@nestjs/common";
import { Errors } from "../common/errors";
import { DatabaseService } from "../database/database.service";
import { computeVerdict, verifyChain } from "../integrity";
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
    // Compare against *local* today — Sri Lanka is UTC+5:30, so a UTC-based
    // "today" rejects early-morning harvests with tomorrow-less dates.
    if (harvestDate > this.todayInColombo()) {
      throw Errors.badRequest("FUTURE_DATE", "Harvest date cannot be in the future");
    }

    try {
      await this.db.transaction(async (client) => {
        const dup = await client.query("SELECT 1 FROM batches WHERE batch_no = $1", [
          dto.batch_no,
        ]);
        if ((dup.rowCount ?? 0) > 0) {
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

      await client.query(
        `INSERT INTO audit_log (user_id, action, entity, entity_id, after)
         VALUES ($1, 'BATCH_CREATED', 'batch', $2, $3::jsonb)`,
        [
          userId,
          dto.id,
          JSON.stringify({ batch_no: dto.batch_no, farm_id: dto.farm_id }),
        ],
      );
    });
    } catch (err) {
      // Recovery happens on the pool — the failed transaction is already
      // rolled back (25P02 would reject any in-transaction recovery query).
      if ((err as { code?: string }).code === "23505") {
        const constraint = (err as { constraint?: string }).constraint;
        if (constraint === "batches_pkey") {
          // Duplicate client UUIDv7: natural idempotency — return the
          // existing batch when it belongs to this user (lost-response retry).
          const row = await this.db.queryOne<{ created_by: string }>(
            "SELECT created_by FROM batches WHERE id = $1",
            [dto.id],
          );
          if (row && row.created_by === userId) return this.get(userId, dto.id);
          throw Errors.conflict("ID_TAKEN", "A batch with this id already exists");
        }
        throw Errors.conflict("BATCH_NO_TAKEN", "Batch number already exists", {
          batch_no: dto.batch_no,
        });
      }
      throw err;
    }

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
    const row = await this.resolveByNo(batchNo);
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
    const row = await this.resolveByNo(batchNo);
    if (!row) return null;
    return this.buildChain(row.id);
  }

  /**
   * Resolve a batch number to its row: current number first, then any
   * former number (batch_no_aliases, migration 0004). Old printed QR
   * labels keep working after P2/exporter renumbering.
   */
  async resolveByNo(batchNo: string): Promise<BatchRow | null> {
    const direct = await this.db.queryOne<BatchRow>(
      "SELECT * FROM batches WHERE batch_no = $1",
      [batchNo],
    );
    if (direct) return direct;
    return this.db.queryOne<BatchRow>(
      `SELECT b.* FROM batches b
       JOIN batch_no_aliases a ON a.batch_id = b.id
       WHERE a.alias = $1`,
      [batchNo],
    );
  }

  async findRowByNo(batchNo: string): Promise<BatchRow | null> {
    return this.resolveByNo(batchNo);
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
    const batch = await this.db.queryOne<BatchRow>(
      "SELECT * FROM batches WHERE id = $1",
      [batchId],
    );
    if (!batch) throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");

    interface ChainEvent {
      batch_no: string;
      event_type: string;
      actor_role: string;
      actor_name: string;
      payload: Record<string, unknown>;
      event_hash: string;
      anchored_at: string | null;
      created_at: string;
    }
    const queryEvents = async (bId: string) =>
      this.db.query<Record<string, unknown>>(
        `SELECT e.event_type, e.actor_role, u.name AS actor_name, e.payload,
                e.event_hash, e.anchored_at, e.created_at
         FROM batch_events e
         JOIN users u ON u.id = e.actor_user_id
         WHERE e.batch_id = $1
         ORDER BY e.created_at ASC, e.id ASC`,
        [bId],
      );

    // Lots are multi-origin (api-spec §8): one flat timeline covering every
    // merged source batch plus the lot's own CREATED/EXPORTED events, each
    // entry tagged with the batch_no it belongs to, and an origins[] list.
    const isLot = batch.stage_suffix === "LOT";
    const origins: Array<{
      batch_no: string;
      farm_name: string | null;
      district: string | null;
      weight_kg: number;
    }> = [];
    const events: ChainEvent[] = [];

    if (isLot) {
      const sources = await this.db.query<{ source_batch_id: string }>(
        "SELECT source_batch_id FROM merge_parents WHERE lot_batch_id = $1 ORDER BY source_batch_id",
        [batchId],
      );
      for (const s of sources) {
        const src = await this.db.queryOne<BatchRow>(
          "SELECT * FROM batches WHERE id = $1",
          [s.source_batch_id],
        );
        if (!src) continue;
        for (const e of await queryEvents(src.id)) {
          events.push({ ...(e as unknown as ChainEvent), batch_no: src.batch_no });
        }
        const srcOrigin = await this.originFor(src);
        origins.push({
          batch_no: src.root_batch_no,
          farm_name: srcOrigin?.farm_name ?? null,
          district: srcOrigin?.district ?? null,
          weight_kg: Number(src.weight_kg),
        });
      }
    }
    for (const e of await queryEvents(batchId)) {
      events.push({ ...(e as unknown as ChainEvent), batch_no: batch.batch_no });
    }

    const origin = isLot ? null : await this.originFor(batch);

    return {
      batch_no: batch.batch_no,
      root_batch_no: batch.root_batch_no,
      origin,
      origins: isLot ? origins : undefined,
      verification: await this.verificationBlock(batchId),
      events: events.map((e) => ({
        batch_no: e.batch_no,
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

  /** Origin farm block for a (root-carrying) batch, honouring privacy level. */
  private async originFor(batch: BatchRow) {
    if (!batch.farm_id) return null;
    const farm = await this.db.queryOne<{
      name: string;
      address_text: string | null;
      area_code: string;
      size_value: string;
      size_unit: string;
      lat: string | null;
      lng: string | null;
      location_public_level: string;
    }>(
      "SELECT name, address_text, area_code, size_value, size_unit, lat, lng, location_public_level FROM farms WHERE id = $1",
      [batch.farm_id],
    );
    if (!farm) return null;
    // Human district name for display (codes are batch-number internals).
    const district = await this.db.queryOne<{ name_en: string }>(
      "SELECT name_en FROM districts WHERE area_code = $1",
      [farm.area_code],
    );
    return {
      farm_name: farm.name,
      address: farm.address_text ?? null,
      district: district?.name_en ?? farm.area_code,
      area_code: farm.area_code,
      size: `${Number(farm.size_value)} ${farm.size_unit}`,
      // Respect the farmer's privacy choice on public surfaces.
      location:
        farm.location_public_level === "EXACT" && farm.lat !== null
          ? { lat: Number(farm.lat), lng: Number(farm.lng) }
          : null,
    };
  }

  /**
   * Tamper-evidence block for a batch: recomputed hash-chain verdict plus the
   * covering Bitcoin (OpenTimestamps) anchors. Single owner of this logic —
   * the verify service reuses it for the public portal.
   */
  async verificationBlock(batchId: string) {
    const events = await this.db.query<Record<string, unknown>>(
      `SELECT batch_id, event_type, actor_user_id, actor_role, payload,
              parent_event_hash, event_hash, created_at
       FROM batch_events WHERE batch_id = $1
       ORDER BY created_at ASC, id ASC`,
      [batchId],
    );
    const chainResult = verifyChain(
      events.map((e) => ({
        batchId: e.batch_id as string,
        eventType: e.event_type as string,
        actorUserId: e.actor_user_id as string,
        actorRole: e.actor_role as string,
        payload: e.payload as Record<string, unknown>,
        parentEventHash: (e.parent_event_hash as string | null) ?? null,
        // node-postgres returns timestamptz as Date; the hash was computed
        // over the original ISO-8601 string, so normalize back.
        occurredAt: new Date(e.created_at as string).toISOString(),
        eventHash: e.event_hash as string,
      })),
    );

    const counts = await this.db.queryOne<{ total: string; anchored: string }>(
      `SELECT count(*)::text AS total,
              count(anchored_at)::text AS anchored
       FROM batch_events WHERE batch_id = $1`,
      [batchId],
    );
    const total = Number(counts?.total ?? 0);
    const anchoredCount = Number(counts?.anchored ?? 0);
    const anchorConfirmed = total > 0 && anchoredCount === total;

    // Only anchors that could cover this batch (created after its first event).
    const firstEventRow = await this.db.queryOne<{ first_at: string }>(
      "SELECT min(created_at)::text AS first_at FROM batch_events WHERE batch_id = $1",
      [batchId],
    );
    const anchors = firstEventRow?.first_at
      ? await this.db.query<{
          network: string;
          merkle_root: string;
          tx_hash: string | null;
          anchored_at: string;
          status: string;
        }>(
          `SELECT network, merkle_root, tx_hash, anchored_at, status FROM chain_anchors
           WHERE anchored_at >= $1::timestamptz
           ORDER BY anchored_at DESC LIMIT 5`,
          [firstEventRow.first_at],
        )
      : [];

    return {
      verdict: computeVerdict({ chainValid: chainResult.valid, anchorConfirmed }),
      event_count: total,
      anchored_count: anchoredCount,
      anchors: anchors.map((a) => ({
        network: a.network,
        merkle_root: a.merkle_root,
        tx_hash: a.tx_hash,
        anchored_at: a.anchored_at,
        status: a.status,
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
      case "RENAMED":
        return `Renumbered ${payload.from ?? "?"} → ${payload.to ?? "?"}`;
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
      // Lets clients gate holder-only actions (transfer button) offline.
      current_holder_id: row.current_holder_id,
      current_holder_role: row.current_holder_role,
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
      verification: await this.verificationBlock(row.id),
    };
  }

  private async hasRole(userId: string, role: string): Promise<boolean> {
    const row = await this.db.queryOne(
      "SELECT 1 FROM user_roles WHERE user_id = $1 AND role = $2",
      [userId, role],
    );
    return row !== null;
  }

  /** Today's date (YYYY-MM-DD) in Asia/Colombo — the farmers' timezone. */
  private todayInColombo(): string {
    return new Intl.DateTimeFormat("en-CA", {
      timeZone: "Asia/Colombo",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(new Date());
  }
}

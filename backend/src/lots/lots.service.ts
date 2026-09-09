import { Injectable } from "@nestjs/common";
import { Errors } from "../common/errors";
import { DatabaseService } from "../database/database.service";
import { allocateExporterCode } from "../common/exporter-codes";
import { uuidv7 } from "../common/uuid";
import { BatchesService } from "../batches/batches.service";
import { LedgerService } from "../batches/ledger.service";
import { CreateLotDto, ListLotsQuery } from "./dto";

/** Statuses a source batch may be exported from. */
const EXPORTABLE_STATUSES = ["HARVESTED", "RECEIVED", "PROCESSED"];

/**
 * Export lots (api-spec §6, Phase 2).
 *
 * The exporter merges 1..N batches they hold into one container lot. The lot
 * IS a batch row (status EXPORTED, created_by = exporter, stage_suffix 'LOT')
 * so events, hashing, anchors, QR and the verify portal work on it unchanged.
 * Source batches move to MERGED with MERGED_IN events pointing at the lot —
 * they keep their full custody history, and the lot's verify view walks their
 * chains for a complete multi-origin provenance page.
 *
 * One-step export (decided): creation applies shipment details and EXPORTED
 * immediately. Exporters have no handover — TRANSFER_MATRIX.EXPORTER is [] —
 * so lots are terminal; POST /lots is the "export" action itself.
 */
@Injectable()
export class LotsService {
  constructor(
    private readonly db: DatabaseService,
    private readonly ledger: LedgerService,
    private readonly batches: BatchesService,
  ) {}

  /** Validates candidates without side effects — the lot-builder screen. */
  async preview(userId: string, dto: CreateLotDto) {
    const held = await this.loadBatches(userId, dto.batch_ids);
    const problems = this.validateCandidates(userId, held, dto.batch_ids);
    if (problems.length > 0) return { ok: false as const, problems };
    return {
      ok: true as const,
      batch_count: held.length,
      total_weight_kg: held.reduce((sum: number, b) => sum + Number(b.weight_kg), 0),
      // Origins power the multi-origin provenance list (per-root identity).
      origins: held.map((b) => ({
        batch_id: b.id,
        batch_no: b.batch_no,
        root_batch_no: b.root_batch_no,
        weight_kg: Number(b.weight_kg),
      })),
    };
  }

  async create(userId: string, dto: CreateLotDto) {
    try {
      return await this.db.transaction(async (client) => {
        // Unique batch_no (0001) is the collision guard; 23505 surfaces as
        // LOT_NO_TAKEN so the offline client regenerates its sequence.
        const dup = await client.query("SELECT 1 FROM batches WHERE batch_no = $1", [
          dto.lot_no,
        ]);
        if ((dup.rowCount ?? 0) > 0) {
          throw Errors.conflict("LOT_NO_TAKEN", "Lot number already exists", {
            lot_no: dto.lot_no,
          });
        }

        // Lock candidate rows for the custody checks + status flips.
        const placeholders = dto.batch_ids.map((_, i) => `$${i + 1}`).join(", ");
        const held = await client.query<{
          id: string;
          batch_no: string;
          root_batch_no: string;
          weight_kg: string;
          status: string;
          current_holder_id: string | null;
        }>(
          `SELECT id, batch_no, root_batch_no, weight_kg, status, current_holder_id
           FROM batches WHERE id IN (${placeholders}) FOR UPDATE`,
          dto.batch_ids,
        );

        const problems = this.validateCandidates(userId, held.rows, dto.batch_ids);
        if (problems.length > 0) {
          throw Errors.badRequest("LOT_CANDIDATES_INVALID", "Lot candidates invalid", problems);
        }

        // exporter_code mirrors farmer_code: allocated once at role
        // acquisition (register/add-role) or lazily here — never recycled.
        await allocateExporterCode(client, userId);

        const totalWeight = held.rows.reduce((sum, b) => sum + Number(b.weight_kg), 0);

        // The lot IS a batch row: holder = exporter, holder role EXPORTER.
        // farm_id/harvest fields stay NULL — origins resolve via merge_parents.
        const lotId = uuidv7();
        await client.query(
          `INSERT INTO batches
             (id, batch_no, weight_kg, status, current_holder_id,
              current_holder_role, root_batch_no, stage_suffix, created_by,
              shipment_date, destination_country, buyer_name, container_no)
           VALUES ($1, $2, $3, 'EXPORTED', $4, 'EXPORTER', $2, 'LOT', $4,
                   $5, $6, $7, $8)`,
          [
            lotId,
            dto.lot_no,
            totalWeight,
            userId,
            dto.shipment_date.slice(0, 10),
            dto.destination_country ?? null,
            dto.buyer_name ?? null,
            dto.container_no ?? null,
          ],
        );

        for (const source of held.rows) {
          await client.query(
            `INSERT INTO merge_parents (lot_batch_id, source_batch_id) VALUES ($1, $2)
             ON CONFLICT DO NOTHING`,
            [lotId, source.id],
          );
          await client.query("UPDATE batches SET status = 'MERGED' WHERE id = $1", [
            source.id,
          ]);
          await this.ledger.appendEvent(client, {
            batchId: source.id,
            eventType: "MERGED_IN",
            actorUserId: userId,
            actorRole: "EXPORTER",
            payload: { lot_id: lotId, lot_no: dto.lot_no },
          });
        }

        await this.ledger.appendEvent(client, {
          batchId: lotId,
          eventType: "CREATED",
          actorUserId: userId,
          actorRole: "EXPORTER",
          payload: {
            lot_no: dto.lot_no,
            batch_count: held.rows.length,
            total_weight_kg: totalWeight,
            roots: held.rows.map((b) => b.root_batch_no),
          },
        });
        await this.ledger.appendEvent(client, {
          batchId: lotId,
          eventType: "EXPORTED",
          actorUserId: userId,
          actorRole: "EXPORTER",
          payload: {
            shipment_date: dto.shipment_date.slice(0, 10),
            destination_country: dto.destination_country ?? null,
            buyer_name: dto.buyer_name ?? null,
            container_no: dto.container_no ?? null,
            batch_ids: held.rows.map((b) => b.id),
            batch_nos: held.rows.map((b) => b.batch_no),
          },
        });

        // Visibility for the exporter on the lot row (trigger also adds it
        // via the EXPORTED event's actor; explicit insert kept for safety,
        // matching the root-batch create path).
        await client.query(
          `INSERT INTO batch_actors (batch_id, user_id, role)
           VALUES ($1, $2, 'EXPORTER') ON CONFLICT DO NOTHING`,
          [lotId, userId],
        );

        await client.query(
          `INSERT INTO audit_log (user_id, action, entity, entity_id, after)
           VALUES ($1, 'LOT_EXPORTED', 'batch', $2, $3::jsonb)`,
          [
            userId,
            lotId,
            JSON.stringify({
              lot_no: dto.lot_no,
              batch_ids: held.rows.map((b) => b.id),
              total_weight_kg: totalWeight,
            }),
          ],
        );

        return {
          lot_id: lotId,
          lot_no: dto.lot_no,
          status: "EXPORTED",
          total_weight_kg: totalWeight,
          batch_nos: held.rows.map((b) => b.batch_no),
          container_no: dto.container_no ?? null,
        };
      });
    } catch (err) {
      if ((err as { code?: string }).code === "23505") {
        throw Errors.conflict("LOT_NO_TAKEN", "Lot number already exists", {
          lot_no: dto.lot_no,
        });
      }
      throw err;
    }
  }

  /** Lot detail: shipment fields + every merged origin chain. */
  async get(userId: string, lotId: string) {
    const lot = await this.db.queryOne<{
      id: string;
      batch_no: string;
      weight_kg: string;
      status: string;
      stage_suffix: string;
      shipment_date: string | null;
      destination_country: string | null;
      buyer_name: string | null;
      container_no: string | null;
      created_at: string;
    }>("SELECT * FROM batches WHERE id = $1", [lotId]);
    if (!lot || lot.stage_suffix !== "LOT") {
      throw Errors.notFound("LOT_NOT_FOUND", "Lot not found");
    }
    if (!(await this.batches.canView(userId, lotId))) {
      throw Errors.notFound("LOT_NOT_FOUND", "Lot not found");
    }

    const sources = await this.db.query<{ batch_id: string }>(
      "SELECT source_batch_id AS batch_id FROM merge_parents WHERE lot_batch_id = $1 ORDER BY source_batch_id",
      [lotId],
    );
    const origins = [];
    for (const s of sources) {
      // Single owner of batch detail — includes chain, origin farm, verdict.
      origins.push(await this.batches.get(userId, s.batch_id));
    }

    return {
      lot_id: lot.id,
      lot_no: lot.batch_no,
      status: lot.status,
      total_weight_kg: Number(lot.weight_kg),
      shipment_date: lot.shipment_date,
      destination_country: lot.destination_country,
      buyer_name: lot.buyer_name,
      container_no: lot.container_no,
      created_at: lot.created_at,
      origins,
    };
  }

  async listMine(userId: string, query: ListLotsQuery) {
    const limit = query.limit ?? 20;
    const offset = query.offset ?? 0;
    const rows = await this.db.query<{
      id: string;
      batch_no: string;
      weight_kg: string;
      status: string;
      shipment_date: string | null;
      container_no: string | null;
      created_at: string;
      source_count: string;
    }>(
      `SELECT b.id, b.batch_no, b.weight_kg, b.status, b.shipment_date,
              b.container_no, b.created_at,
              (SELECT count(*)::text FROM merge_parents mp
                WHERE mp.lot_batch_id = b.id) AS source_count
       FROM batches b
       WHERE b.stage_suffix = 'LOT' AND b.created_by = $1
       ORDER BY b.created_at DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset],
    );
    const countRow = await this.db.queryOne<{ n: string }>(
      "SELECT count(*)::text AS n FROM batches WHERE stage_suffix = 'LOT' AND created_by = $1",
      [userId],
    );
    return {
      data: rows.map((r) => ({
        lot_id: r.id,
        lot_no: r.batch_no,
        status: r.status,
        total_weight_kg: Number(r.weight_kg),
        shipment_date: r.shipment_date,
        container_no: r.container_no,
        batch_count: Number(r.source_count),
        created_at: r.created_at,
      })),
      meta: { total: Number(countRow?.n ?? 0), limit, offset },
    };
  }

  private async loadBatches(userId: string, batchIds: string[]) {
    if (batchIds.length === 0) return [];
    const placeholders = batchIds.map((_, i) => `$${i + 1}`).join(", ");
    const rows = await this.db.query<{
      id: string;
      batch_no: string;
      root_batch_no: string;
      weight_kg: string;
      status: string;
      current_holder_id: string | null;
    }>(
      `SELECT id, batch_no, root_batch_no, weight_kg, status, current_holder_id
       FROM batches WHERE id IN (${placeholders})`,
      batchIds,
    );
    return rows;
  }

  /** Dedupe + existence + holder + exportable-status checks → problems[]. */
  private validateCandidates(
    userId: string,
    held: Array<{
      id: string;
      status: string;
      current_holder_id: string | null;
    }>,
    requestedIds: string[],
  ) {
    const problems: Array<{ batch_id: string; reason: string }> = [];
    const seen = new Set<string>();
    const byId = new Map(held.map((b) => [b.id, b]));

    for (const id of requestedIds) {
      if (seen.has(id)) {
        problems.push({ batch_id: id, reason: "DUPLICATE" });
        continue;
      }
      seen.add(id);
      const batch = byId.get(id);
      if (!batch) {
        problems.push({ batch_id: id, reason: "NOT_FOUND" });
        continue;
      }
      if (batch.current_holder_id !== userId) {
        problems.push({ batch_id: id, reason: "NOT_HELD_BY_EXPORTER" });
        continue;
      }
      if (!EXPORTABLE_STATUSES.includes(batch.status)) {
        problems.push({ batch_id: id, reason: `STATUS_${batch.status}` });
      }
    }
    return problems;
  }
}

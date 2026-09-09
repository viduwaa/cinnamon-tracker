import { Injectable } from "@nestjs/common";
import { Errors } from "../common/errors";
import { DatabaseService } from "../database/database.service";
import { appendStage, EX_CUSTOM_NO_REGEX } from "./numbering";
import { LedgerService } from "./ledger.service";
import { ProcessBatchDto, RenameBatchDto } from "./dto";

/**
 * Processing stages (api-spec §5).
 *
 * P1 (peeling/quilling): suffix /P1 is appended automatically — never
 * manually editable. P2 (grinding): suffix /P2 by default, or the processor
 * may supply a custom number matching `AA-JJJ-SS-YYYY-P2-CODE`.
 *
 * Lineage is immutable regardless of naming: root_batch_no never changes,
 * every former number is kept resolvable in batch_no_aliases (0004), and a
 * custom renumber is a first-class RENAMED ledger event.
 *
 * Receiving stays the existing transfers flow (IN_TRANSIT → accept →
 * RECEIVED); processing additionally requires RECEIVED/PROCESSED status.
 */
const PROCESSABLE_STATUSES = ["RECEIVED", "PROCESSED"];
const EXPORTABLE_STATUSES = ["HARVESTED", "RECEIVED", "PROCESSED"];

@Injectable()
export class ProcessingService {
  constructor(
    private readonly db: DatabaseService,
    private readonly ledger: LedgerService,
  ) {}

  async process(userId: string, batchId: string, dto: ProcessBatchDto) {
    try {
      return await this.db.transaction(async (client) => {
      const result = await client.query<{
        id: string;
        batch_no: string;
        weight_kg: string;
        status: string;
        current_holder_id: string | null;
        current_holder_role: string | null;
        root_batch_no: string;
        stage_suffix: string;
      }>("SELECT * FROM batches WHERE id = $1 FOR UPDATE", [batchId]);
      const batch = result.rows[0];
      if (!batch) throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");

      if (batch.current_holder_id !== userId) {
        throw Errors.forbidden("NOT_HOLDER", "You do not hold this batch");
      }
      if (batch.current_holder_role !== "PROCESSOR_L1" && batch.current_holder_role !== "PROCESSOR_L2") {
        throw Errors.forbidden(
          "ROLE_REQUIRED",
          "Only processors can record processing",
        );
      }
      if (!PROCESSABLE_STATUSES.includes(batch.status)) {
        throw Errors.conflict(
          "NOT_PROCESSABLE",
          `Batch in status ${batch.status} cannot be processed (accept it first)`,
        );
      }

      const stage = batch.current_holder_role === "PROCESSOR_L1" ? "P1" : "P2";

      // api-spec §5: P1's number is never manually editable; only P2 may
      // supply a custom name.
      if (stage === "P1" && dto.batch_no) {
        throw Errors.badRequest(
          "P1_NOT_RENAMABLE",
          "Processing stage P1 cannot rename a batch",
        );
      }

      const newSuffix = batch.stage_suffix.includes(`/${stage}`)
        ? batch.stage_suffix
        : `${batch.stage_suffix}/${stage}`;

      // Only P2 may send a custom number — enforced below by the manual
      // P1_NOT_RENAMABLE check (the DTO cannot express "P1 only").
      let newBatchNo: string;
      if (dto.batch_no) {
        newBatchNo = dto.batch_no;
      } else {
        try {
          newBatchNo = appendStage(batch.batch_no, batch.stage_suffix, stage);
        } catch {
          // Same stage twice (e.g. a P2 re-processing): number stays, only
          // the PROCESSED event is appended.
          newBatchNo = batch.batch_no;
        }
      }

      const renamed = newBatchNo !== batch.batch_no;

      if (renamed) {
        // Reserve the new number first — a taken number aborts the whole
        // processing transaction (409 BATCH_NO_TAKEN).
        const dup = await client.query("SELECT 1 FROM batches WHERE batch_no = $1", [
          newBatchNo,
        ]);
        if ((dup.rowCount ?? 0) > 0) {
          throw Errors.conflict("BATCH_NO_TAKEN", "Batch number already exists", {
            batch_no: newBatchNo,
          });
        }
        await client.query("INSERT INTO batch_no_aliases (alias, batch_id) VALUES ($1, $2) ON CONFLICT DO NOTHING", [
          batch.batch_no,
          batchId,
        ]);
      }

      await client.query(
        `UPDATE batches
         SET batch_no = $1, stage_suffix = $2, status = 'PROCESSED',
             weight_kg = $3
         WHERE id = $4`,
        [newBatchNo, newSuffix, dto.output_weight_kg, batchId],
      );

      await this.ledger.appendEvent(client, {
        batchId,
        eventType: "PROCESSED",
        actorUserId: userId,
        actorRole: batch.current_holder_role,
        payload: {
          action: "PROCESSED",
          output_weight_kg: dto.output_weight_kg,
          batch_no: renamed ? newBatchNo : null,
          stage_suffix: newSuffix,
        },
      });

      if (renamed) {
        await this.ledger.appendEvent(client, {
          batchId,
          eventType: "RENAMED",
          actorUserId: userId,
          actorRole: batch.current_holder_role,
          payload: { from: batch.batch_no, to: newBatchNo },
        });
      }

      await client.query(
        `INSERT INTO audit_log (user_id, action, entity, entity_id, after)
         VALUES ($1, 'BATCH_PROCESSED', 'batch', $2, $3::jsonb)`,
        [
          userId,
          batchId,
          JSON.stringify({
            from_status: batch.status,
            output_weight_kg: dto.output_weight_kg,
            renamed,
            batch_no: newBatchNo,
          }),
        ],
      );

      return {
        batch_id: batchId,
        batch_no: newBatchNo,
        previous_batch_no: renamed ? batch.batch_no : null,
        root_batch_no: batch.root_batch_no,
        stage_suffix: newSuffix,
        status: "PROCESSED",
        weight_kg: dto.output_weight_kg,
      };
      });
    } catch (err) {
      // Concurrent rename to the same number loses the unique-index race
      // (23505) — surface as the same 409 the pre-check produces.
      if ((err as { code?: string }).code === "23505") {
        throw Errors.conflict("BATCH_NO_TAKEN", "Batch number already exists", {
          batch_no: dto.batch_no ?? null,
        });
      }
      throw err;
    }
  }

  /**
   * Exporter renumbering of a held batch (grill Q3): default appends "/EX"
   * to the current number; a custom number must match the EX pattern.
   * Mirrors processing renames — alias-preserved, RENAMED event, lineage
   * untouched. Lot rows are named at creation and cannot be renamed here.
   */
  async rename(userId: string, batchId: string, dto: RenameBatchDto) {
    try {
      return await this.db.transaction(async (client) => {
        const result = await client.query<{
          id: string;
          batch_no: string;
          status: string;
          current_holder_id: string | null;
          current_holder_role: string | null;
          stage_suffix: string;
        }>("SELECT * FROM batches WHERE id = $1 FOR UPDATE", [batchId]);
        const batch = result.rows[0];
        if (!batch) throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");
        if (batch.current_holder_id !== userId) {
          throw Errors.forbidden("NOT_HOLDER", "You do not hold this batch");
        }
        if (batch.current_holder_role !== "EXPORTER") {
          throw Errors.forbidden(
            "ROLE_REQUIRED",
            "Only the exporter can rename a batch here",
          );
        }
        if (batch.stage_suffix === "LOT") {
          throw Errors.badRequest(
            "LOT_NOT_RENAMABLE",
            "Lot numbers are set at creation",
          );
        }
        if (!EXPORTABLE_STATUSES.includes(batch.status)) {
          throw Errors.conflict(
            "NOT_RENAMABLE",
            `Batch in status ${batch.status} cannot be renamed`,
          );
        }
        if (batch.stage_suffix.includes("/EX")) {
          throw Errors.conflict("ALREADY_RENAMED", "Batch already carries /EX");
        }

        const newBatchNo = dto.batch_no ?? appendStage(batch.batch_no, batch.stage_suffix, "EX");
        const dup = await client.query("SELECT 1 FROM batches WHERE batch_no = $1", [
          newBatchNo,
        ]);
        if ((dup.rowCount ?? 0) > 0) {
          throw Errors.conflict("BATCH_NO_TAKEN", "Batch number already exists", {
            batch_no: newBatchNo,
          });
        }
        await client.query(
          "INSERT INTO batch_no_aliases (alias, batch_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
          [batch.batch_no, batchId],
        );
        await client.query("UPDATE batches SET batch_no = $1 WHERE id = $2", [
          newBatchNo,
          batchId,
        ]);
        await this.ledger.appendEvent(client, {
          batchId,
          eventType: "RENAMED",
          actorUserId: userId,
          actorRole: "EXPORTER",
          payload: { from: batch.batch_no, to: newBatchNo },
        });

        await client.query(
          `INSERT INTO audit_log (user_id, action, entity, entity_id, after)
           VALUES ($1, 'BATCH_RENAMED', 'batch', $2, $3::jsonb)`,
          [userId, batchId, JSON.stringify({ batch_no: newBatchNo })],
        );

        return {
          batch_id: batchId,
          batch_no: newBatchNo,
          previous_batch_no: batch.batch_no,
        };
      });
    } catch (err) {
      if ((err as { code?: string }).code === "23505") {
        throw Errors.conflict("BATCH_NO_TAKEN", "Batch number already exists", {
          batch_no: dto.batch_no ?? null,
        });
      }
      throw err;
    }
  }

  /** Suggested next number — lets the P2 screen prefill/customize. */
  async suggest(userId: string, batchId: string) {
    const row = await this.db.queryOne<{
      batch_no: string;
      stage_suffix: string;
      current_holder_id: string | null;
      current_holder_role: string | null;
      status: string;
    }>("SELECT * FROM batches WHERE id = $1", [batchId]);
    if (!row) throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");
    if (row.current_holder_id !== userId) {
      throw Errors.forbidden("NOT_HOLDER", "You do not hold this batch");
    }
    if (row.current_holder_role !== "PROCESSOR_L1" && row.current_holder_role !== "PROCESSOR_L2") {
      throw Errors.forbidden("ROLE_REQUIRED", "Only processors can process");
    }

    const stage = row.current_holder_role === "PROCESSOR_L1" ? "P1" : "P2";
    let suggested: string;
    try {
      suggested = appendStage(row.batch_no, row.stage_suffix, stage);
    } catch {
      suggested = row.batch_no;
    }
    return { batch_id: batchId, stage, suggested_batch_no: suggested };
  }
}

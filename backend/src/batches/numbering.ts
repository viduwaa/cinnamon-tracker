/**
 * Batch/lot numbering formats (api-spec §5–§6, migration 0004).
 *
 * Root:    AA-JJJ-SS-YYYY-FM-CODE-T|Q          (farmer, client-generated)
 * Stages:  root gets "/P1" then "/P1/P2"…      (P1 forced, P2 optional custom)
 * P2 custom:  AA-JJJ-SS-YYYY-P2-CODE
 * EX custom:  AA-JJJ-SS-YYYY-EX-CODE
 * Lots:    EX-SSS-YYYY-EXP-CODE                (exporter, client-generated)
 *
 * Renaming keeps lineage: batches.root_batch_no never changes, every number
 * a batch has had is resolvable via batch_no_aliases (migration 0004).
 */

export const P2_CUSTOM_NO_REGEX = /^[A-Z]{2}-\d{3}-\d{2}-\d{4}-P2-[A-Z0-9]{1,4}$/;
export const EX_CUSTOM_NO_REGEX = /^[A-Z]{2}-\d{3}-\d{2}-\d{4}-EX-[A-Z0-9]{1,4}$/;
export const LOT_NO_REGEX = /^EX-\d{3}-\d{4}-EXP-[A-Z0-9]{1,4}$/;
/** ISO 6346 container code: 4 letters + 7 digits (e.g. MSKU1234567). */
export const CONTAINER_NO_REGEX = /^[A-Z]{4}\d{7}$/;

/** Appends a stage suffix ("/P1", "/P2", "/EX"). Rejects double-processing. */
export function appendStage(currentBatchNo: string, stageSuffix: string, stage: string): string {
  if (stageSuffix.includes(`/${stage}`)) {
    throw new Error(`stage ${stage} already applied`);
  }
  return `${currentBatchNo}/${stage}`;
}

/**
 * Single owner of "apply a processing/export stage to a batch": idempotent —
 * re-applying the same stage returns the number unchanged. Rename is the
 * caller's decision; suffix and number always move together.
 */
export function applyStage(
  currentBatchNo: string,
  stageSuffix: string,
  stage: string,
): { batchNo: string; suffix: string; changed: boolean } {
  if (stageSuffix.includes(`/${stage}`)) {
    return { batchNo: currentBatchNo, suffix: stageSuffix, changed: false };
  }
  return {
    batchNo: `${currentBatchNo}/${stage}`,
    suffix: `${stageSuffix}/${stage}`,
    changed: true,
  };
}

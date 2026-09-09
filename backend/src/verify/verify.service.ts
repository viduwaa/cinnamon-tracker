import { Injectable } from "@nestjs/common";
import { BatchesService } from "../batches/batches.service";

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
  /** Export lots only: one entry per merged source batch. */
  origins?: Array<Record<string, unknown>>;
  chain: Array<{
    batch_no?: string;
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
    private readonly batches: BatchesService,
  ) {}

  async verify(batchNo: string): Promise<VerifyResult | null> {
    const chainData = await this.batches.publicChain(batchNo);
    if (!chainData) return null;

    const batch = await this.batches.findRowByNo(batchNo);
    if (!batch) return null;

    // Verdict + anchors come from the single owner (BatchesService) so the
    // public portal and the app can never disagree about a batch's state.
    const verification = await this.batches.verificationBlock(batch.id);

    return {
      batch_no: batch.batch_no,
      verdict: verification.verdict,
      anchors: verification.anchors.map((a) => ({
        network: a.network,
        tx_hash: a.tx_hash,
        anchored_at: a.anchored_at,
        status: a.status,
      })),
      origin: chainData.origin,
      origins: chainData.origins,
      chain: chainData.events.map((e) => ({
        ...e,
        verified: verification.verdict !== "TAMPERED",
      })),
    };
  }
}

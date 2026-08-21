/**
 * Verification verdict for the public QR page and API.
 *
 * TAMPERED  — recomputed hashes disagree with stored hashes (or chain link broken).
 * AUTHENTIC — chain intact AND the Merkle root is confirmed by an external witness.
 * PENDING   — chain intact but not yet anchored (normal between nightly runs,
 *             or while the anchor network is unreachable).
 */

export type Verdict = "AUTHENTIC" | "TAMPERED" | "PENDING";

export interface VerdictInput {
  chainValid: boolean;
  anchorConfirmed: boolean;
}

export function computeVerdict(input: VerdictInput): Verdict {
  if (!input.chainValid) return "TAMPERED";
  return input.anchorConfirmed ? "AUTHENTIC" : "PENDING";
}

import { createHash } from "node:crypto";

/**
 * Hash-chained event ledger — the "our own integrity layer" half of the
 * blockchain strategy. Every event hash commits to its parent's hash, so any
 * silent database edit breaks the chain and is detectable by recomputation.
 *
 * Field order in the hash input is part of the spec and must never change;
 * append-only evolution only (see docs/blockchain-discussion.md).
 */

/** Inputs required to hash one ledger event. */
export interface ChainEventInput {
  batchId: string;
  eventType: string;
  actorUserId: string;
  actorRole: string;
  payload: unknown;
  parentEventHash: string | null;
  /** ISO-8601 UTC with millisecond precision; backend normalizes before hashing. */
  occurredAt: string;
}

export interface StoredEvent extends ChainEventInput {
  eventHash: string;
}

export const GENESIS_PARENT = "GENESIS";

/** Canonical JSON: object keys sorted recursively, so semantically equal
 * payloads always hash identically regardless of insertion order. */
export function canonicalJson(value: unknown): string {
  return JSON.stringify(sortValue(value));
}

function sortValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortValue);
  if (value !== null && typeof value === "object") {
    const sorted: Record<string, unknown> = {};
    for (const key of Object.keys(value as Record<string, unknown>).sort()) {
      sorted[key] = sortValue((value as Record<string, unknown>)[key]);
    }
    return sorted;
  }
  return value;
}

export function computeEventHash(input: ChainEventInput): string {
  const parts = [
    input.parentEventHash ?? GENESIS_PARENT,
    input.batchId,
    input.eventType,
    input.actorUserId,
    input.actorRole,
    canonicalJson(input.payload),
    input.occurredAt,
  ];
  return createHash("sha256").update(parts.join("\n"), "utf8").digest("hex");
}

/**
 * Recompute hashes for one batch's event chain, oldest first.
 * Returns the first broken event hash, or valid.
 */
export function verifyChain(
  events: StoredEvent[],
): { valid: true } | { valid: false; brokenAt: string } {
  let expectedParent: string | null = null;
  for (const event of events) {
    const parent = event.parentEventHash ?? null;
    if (parent !== expectedParent) {
      return { valid: false, brokenAt: event.eventHash };
    }
    if (computeEventHash(event) !== event.eventHash) {
      return { valid: false, brokenAt: event.eventHash };
    }
    expectedParent = event.eventHash;
  }
  return { valid: true };
}

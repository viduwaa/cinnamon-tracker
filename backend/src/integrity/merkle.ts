import { createHash } from "node:crypto";

/**
 * Merkle tree over event hashes. The nightly anchor job computes the root
 * over all unanchored events and submits it to an external witness
 * (OpenTimestamps today, optional Polygon later). Proofs allow selective
 * disclosure later without revealing the whole ledger.
 *
 * Conventions: leaves are 32-byte hex strings (event hashes); leaf nodes are
 * H(leafBytes); internal nodes are H(left || right); an odd node is paired
 * with itself.
 */

export interface MerkleProofStep {
  hash: string;
  side: "left" | "right";
}

function sha256(data: Buffer | Uint8Array): Buffer {
  return createHash("sha256").update(data).digest();
}

function hashLeaf(leafHex: string): Buffer {
  return sha256(Buffer.from(leafHex, "hex"));
}

function hashPair(a: Buffer, b: Buffer): Buffer {
  return sha256(Buffer.concat([a, b]));
}

function buildLevels(leafHashesHex: string[]): Buffer[][] {
  if (leafHashesHex.length === 0) {
    throw new Error("merkle: empty leaf set");
  }
  const levels: Buffer[][] = [leafHashesHex.map(hashLeaf)];
  while (levels[levels.length - 1].length > 1) {
    const prev = levels[levels.length - 1];
    const next: Buffer[] = [];
    for (let i = 0; i < prev.length; i += 2) {
      next.push(hashPair(prev[i], prev[i + 1] ?? prev[i]));
    }
    levels.push(next);
  }
  return levels;
}

export function merkleRoot(leafHashesHex: string[]): string {
  const levels = buildLevels(leafHashesHex);
  return levels[levels.length - 1][0].toString("hex");
}

export function merkleProof(
  leafHashesHex: string[],
  index: number,
): MerkleProofStep[] {
  if (index < 0 || index >= leafHashesHex.length) {
    throw new Error("merkleProof: index out of range");
  }
  const levels = buildLevels(leafHashesHex);
  const proof: MerkleProofStep[] = [];
  let idx = index;
  for (let level = 0; level < levels.length - 1; level++) {
    const nodes = levels[level];
    const siblingIndex = idx % 2 === 0 ? idx + 1 : idx - 1;
    const sibling = nodes[siblingIndex] ?? nodes[idx];
    proof.push({
      hash: sibling.toString("hex"),
      side: idx % 2 === 0 ? "right" : "left",
    });
    idx = Math.floor(idx / 2);
  }
  return proof;
}

export function verifyMerkleProof(
  leafHex: string,
  proof: MerkleProofStep[],
  rootHex: string,
): boolean {
  let current = hashLeaf(leafHex);
  for (const step of proof) {
    const sibling = Buffer.from(step.hash, "hex");
    current =
      step.side === "left"
        ? hashPair(sibling, current)
        : hashPair(current, sibling);
  }
  return current.toString("hex") === rootHex;
}

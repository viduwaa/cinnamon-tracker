import { createHash } from "node:crypto";
import { describe, expect, it } from "vitest";
import { merkleProof, merkleRoot, verifyMerkleProof } from "./merkle.js";

const leaf = (s: string) => createHash("sha256").update(s).digest("hex");

describe("merkleRoot", () => {
  it("throws on an empty leaf set", () => {
    expect(() => merkleRoot([])).toThrow("empty leaf set");
  });

  it("matches an independently computed two-leaf root", () => {
    const a = leaf("a");
    const b = leaf("b");
    const expected = createHash("sha256")
      .update(
        Buffer.concat([
          createHash("sha256").update(Buffer.from(a, "hex")).digest(),
          createHash("sha256").update(Buffer.from(b, "hex")).digest(),
        ]),
      )
      .digest("hex");
    expect(merkleRoot([a, b])).toBe(expected);
  });

  it("handles an odd number of leaves", () => {
    expect(() => merkleRoot([leaf("a"), leaf("b"), leaf("c")])).not.toThrow();
  });

  it("is order-sensitive", () => {
    const leaves = [leaf("a"), leaf("b"), leaf("c")];
    expect(merkleRoot(leaves)).not.toBe(merkleRoot([leaf("b"), leaf("a"), leaf("c")]));
  });

  it("changes when any leaf changes", () => {
    const leaves = [leaf("a"), leaf("b"), leaf("c"), leaf("d")];
    const tampered = [...leaves];
    tampered[2] = leaf("evil");
    expect(merkleRoot(leaves)).not.toBe(merkleRoot(tampered));
  });
});

describe("merkle proofs", () => {
  for (const size of [1, 2, 3, 4, 7]) {
    it(`verifies every index for ${size} leaves`, () => {
      const leaves = Array.from({ length: size }, (_, i) => leaf(`leaf-${i}`));
      const root = merkleRoot(leaves);
      leaves.forEach((l, i) => {
        const proof = merkleProof(leaves, i);
        expect(verifyMerkleProof(l, proof, root)).toBe(true);
      });
    });
  }

  it("rejects a tampered leaf", () => {
    const leaves = [leaf("a"), leaf("b"), leaf("c"), leaf("d")];
    const root = merkleRoot(leaves);
    const proof = merkleProof(leaves, 1);
    expect(verifyMerkleProof(leaf("evil"), proof, root)).toBe(false);
  });

  it("rejects proofs against the wrong root", () => {
    const leaves = [leaf("a"), leaf("b")];
    const proof = merkleProof(leaves, 0);
    expect(verifyMerkleProof(leaves[0], proof, leaf("other-root"))).toBe(false);
  });

  it("throws on out-of-range index", () => {
    expect(() => merkleProof([leaf("a")], 1)).toThrow("index out of range");
  });
});

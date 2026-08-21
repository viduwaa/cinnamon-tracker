import { describe, expect, it } from "vitest";
import {
  canonicalJson,
  computeEventHash,
  verifyChain,
  type ChainEventInput,
  type StoredEvent,
} from "./hash-chain.js";

function makeInput(
  parent: string | null,
  overrides: Partial<ChainEventInput> = {},
): ChainEventInput {
  return {
    batchId: "batch-1",
    eventType: "CREATED",
    actorUserId: "user-1",
    actorRole: "FARMER",
    payload: { weight_kg: 120.5, tree_count: 45 },
    parentEventHash: parent,
    occurredAt: "2026-08-17T06:30:00.000Z",
    ...overrides,
  };
}

function makeChain(): StoredEvent[] {
  const first: StoredEvent = {
    ...makeInput(null),
    eventHash: "",
  };
  first.eventHash = computeEventHash(first);

  const second: StoredEvent = {
    ...makeInput(first.eventHash, {
      eventType: "TRANSFERRED",
      payload: { to_user: "user-2", kind: "SALE" },
      occurredAt: "2026-08-18T09:00:00.000Z",
    }),
    eventHash: "",
  };
  second.eventHash = computeEventHash(second);

  const third: StoredEvent = {
    ...makeInput(second.eventHash, {
      eventType: "PROCESSED",
      actorUserId: "user-2",
      actorRole: "PROCESSOR_L1",
      payload: { output_weight_kg: 98 },
      occurredAt: "2026-08-20T14:00:00.000Z",
    }),
    eventHash: "",
  };
  third.eventHash = computeEventHash(third);

  return [first, second, third];
}

describe("canonicalJson", () => {
  it("is independent of key insertion order, including nested objects", () => {
    expect(canonicalJson({ b: 1, a: { d: 2, c: [3, 2] } })).toBe(
      canonicalJson({ a: { c: [3, 2], d: 2 }, b: 1 }),
    );
  });

  it("keeps array order significant", () => {
    expect(canonicalJson([1, 2])).not.toBe(canonicalJson([2, 1]));
  });
});

describe("computeEventHash", () => {
  it("is deterministic", () => {
    const input = makeInput(null);
    expect(computeEventHash(input)).toBe(computeEventHash(input));
  });

  it("is independent of payload key order", () => {
    const a = makeInput(null, { payload: { weight_kg: 1, tree_count: 2 } });
    const b = makeInput(null, { payload: { tree_count: 2, weight_kg: 1 } });
    expect(computeEventHash(a)).toBe(computeEventHash(b));
  });

  it("changes when any field changes", () => {
    const base = computeEventHash(makeInput(null));
    const variants = [
      makeInput(null, { payload: { weight_kg: 120.6, tree_count: 45 } }),
      makeInput(null, { actorUserId: "user-other" }),
      makeInput(null, { actorRole: "COLLECTOR" }),
      makeInput(null, { eventType: "PROCESSED" }),
      makeInput(null, { occurredAt: "2026-08-17T06:30:00.001Z" }),
      makeInput("deadbeef"),
    ];
    for (const variant of variants) {
      expect(computeEventHash(variant)).not.toBe(base);
    }
  });
});

describe("verifyChain", () => {
  it("accepts an intact chain", () => {
    expect(verifyChain(makeChain())).toEqual({ valid: true });
  });

  it("detects a tampered payload", () => {
    const chain = makeChain();
    chain[1] = { ...chain[1], payload: { to_user: "user-9", kind: "SALE" } };
    const result = verifyChain(chain);
    expect(result.valid).toBe(false);
    if (!result.valid) expect(result.brokenAt).toBe(chain[1].eventHash);
  });

  it("detects a broken parent link", () => {
    const chain = makeChain();
    chain[2] = { ...chain[2], parentEventHash: "forged" };
    const result = verifyChain(chain);
    expect(result.valid).toBe(false);
    if (!result.valid) expect(result.brokenAt).toBe(chain[2].eventHash);
  });

  it("rejects a chain whose first event claims a parent", () => {
    const chain = makeChain();
    chain[0] = { ...chain[0], parentEventHash: "deadbeef" };
    expect(verifyChain(chain).valid).toBe(false);
  });
});

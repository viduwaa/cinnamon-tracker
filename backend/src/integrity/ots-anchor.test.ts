import { describe, expect, it } from "vitest";
import { AnchorError, stampDigest } from "./ots-anchor.js";

const DIGEST = "ab".repeat(32);

function okFetch(bytes: number[]): typeof fetch {
  return (async () =>
    new Response(new Uint8Array(bytes), { status: 200 })) as typeof fetch;
}

describe("stampDigest", () => {
  it("rejects malformed digests", async () => {
    await expect(stampDigest("xyz")).rejects.toThrow(AnchorError);
    await expect(stampDigest("ab".repeat(31))).rejects.toThrow(AnchorError);
  });

  it("stores attestations from every reachable calendar", async () => {
    const results = await stampDigest(
      DIGEST,
      ["https://cal-one.test", "https://cal-two.test"],
      okFetch([1, 2, 3]),
    );
    expect(results).toHaveLength(2);
    expect(results[0].attestationHex).toBe("010203");
    expect(results[0].digestHex).toBe(DIGEST);
    expect(results[0].calendarUrl).toBe("https://cal-one.test");
  });

  it("succeeds when at least one calendar responds", async () => {
    let call = 0;
    const flakyFetch = (async () => {
      call += 1;
      if (call === 1) throw new Error("network down");
      return new Response(new Uint8Array([9]), { status: 200 });
    }) as typeof fetch;
    const results = await stampDigest(
      DIGEST,
      ["https://down.test", "https://up.test"],
      flakyFetch,
    );
    expect(results).toHaveLength(1);
    expect(results[0].calendarUrl).toBe("https://up.test");
  });

  it("throws AnchorError only when all calendars fail", async () => {
    const failingFetch = (async () =>
      new Response(null, { status: 503 })) as typeof fetch;
    await expect(
      stampDigest(DIGEST, ["https://a.test", "https://b.test"], failingFetch),
    ).rejects.toThrow(/all calendars failed/);
  });
});

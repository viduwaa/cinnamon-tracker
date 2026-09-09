import { describe, expect, it } from "vitest";
import { decodeAlphaCode, encodeAlphaCode } from "./codes";

describe("alpha codes (farmer_code / exporter_code)", () => {
  it("round-trips", () => {
    for (let n = 1; n <= 60; n++) {
      expect(decodeAlphaCode(encodeAlphaCode(n))).toBe(n);
    }
  });
  it("matches farmer_code conventions already in the data", () => {
    expect(encodeAlphaCode(1)).toBe("A");
    expect(encodeAlphaCode(26)).toBe("Z");
    expect(encodeAlphaCode(27)).toBe("AA");
  });
  it("decodes junk as 0", () => {
    expect(decodeAlphaCode("a1")).toBe(0);
    expect(decodeAlphaCode("")).toBe(0);
  });
});

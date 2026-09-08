import { describe, expect, it } from "vitest";
import { normalizeMobile } from "./phone";

describe("normalizeMobile", () => {
  it("normalizes standard Sri Lankan mobile with 0", () => {
    expect(normalizeMobile("0771234567")).toBe("+94771234567");
    expect(normalizeMobile("071 234 5678")).toBe("+94712345678");
    expect(normalizeMobile("077-123-4567")).toBe("+94771234567");
    expect(normalizeMobile("(077) 1234567")).toBe("+94771234567");
  });

  it("normalizes Sri Lankan mobile without leading 0 (9 digits)", () => {
    expect(normalizeMobile("771234567")).toBe("+94771234567");
    expect(normalizeMobile("712345678")).toBe("+94712345678");
  });

  it("normalizes Sri Lankan mobile with 94 but missing +", () => {
    expect(normalizeMobile("94771234567")).toBe("+94771234567");
  });

  it("preserves already normalized +94 numbers", () => {
    expect(normalizeMobile("+94771234567")).toBe("+94771234567");
    expect(normalizeMobile("+94 77 123 4567")).toBe("+94771234567");
  });

  it("normalizes numbers with international 00 prefix", () => {
    expect(normalizeMobile("0094771234567")).toBe("+94771234567");
    expect(normalizeMobile("0012025550123")).toBe("+12025550123");
  });

  it("preserves international numbers with country codes", () => {
    expect(normalizeMobile("+1 (202) 555-0123")).toBe("+12025550123");
    expect(normalizeMobile("+44 7911 123456")).toBe("+447911123456");
    expect(normalizeMobile("+91 98765 43210")).toBe("+919876543210");
    expect(normalizeMobile("+61 412 345 678")).toBe("+61412345678");
  });

  it("handles empty or blank input gracefully", () => {
    expect(normalizeMobile("")).toBe("");
    expect(normalizeMobile("   ")).toBe("");
  });
});

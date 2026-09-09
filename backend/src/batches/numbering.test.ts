import { describe, expect, it } from "vitest";
import {
  appendStage,
  CONTAINER_NO_REGEX,
  EX_CUSTOM_NO_REGEX,
  LOT_NO_REGEX,
  P2_CUSTOM_NO_REGEX,
} from "./numbering";

describe("P2 custom batch numbers", () => {
  it("accepts the spec'd shape", () => {
    expect(P2_CUSTOM_NO_REGEX.test("GM-172-01-2026-P2-NIMA")).toBe(true);
    expect(P2_CUSTOM_NO_REGEX.test("GM-172-01-2026-P2-A1")).toBe(true);
  });
  it("rejects FM-root and lot shapes", () => {
    expect(P2_CUSTOM_NO_REGEX.test("GM-172-01-2026-FM-A-T")).toBe(false);
    expect(P2_CUSTOM_NO_REGEX.test("EX-001-2026-EXP-A")).toBe(false);
  });
});

describe("EX custom batch numbers", () => {
  it("accepts exporter renumbering", () => {
    expect(EX_CUSTOM_NO_REGEX.test("GM-172-01-2026-EX-SPIC")).toBe(true);
  });
  it("rejects P2 shape", () => {
    expect(EX_CUSTOM_NO_REGEX.test("GM-172-01-2026-P2-A")).toBe(false);
  });
});

describe("lot numbers", () => {
  it("accepts EX-SSS-YYYY-EXP-CODE", () => {
    expect(LOT_NO_REGEX.test("EX-001-2026-EXP-A")).toBe(true);
    expect(LOT_NO_REGEX.test("EX-042-2026-EXP-SPIC")).toBe(true);
  });
  it("rejects batch-shaped input", () => {
    expect(LOT_NO_REGEX.test("GM-172-01-2026-FM-A-T")).toBe(false);
    expect(LOT_NO_REGEX.test("EX-1-2026-EXP-A")).toBe(false);
  });
});

describe("container numbers", () => {
  it("accepts ISO 6346 shape", () => {
    expect(CONTAINER_NO_REGEX.test("MSKU1234567")).toBe(true);
  });
  it("rejects short/wrong shapes", () => {
    expect(CONTAINER_NO_REGEX.test("MSKU123456")).toBe(false);
    expect(CONTAINER_NO_REGEX.test("1234567ABCD")).toBe(false);
  });
});

describe("appendStage", () => {
  it("appends /P1 then /P2 to the current number", () => {
    expect(appendStage("GM-172-01-2026-FM-A-T", "", "P1")).toBe(
      "GM-172-01-2026-FM-A-T/P1",
    );
    expect(appendStage("GM-172-01-2026-FM-A-T/P1", "/P1", "P2")).toBe(
      "GM-172-01-2026-FM-A-T/P1/P2",
    );
  });
  it("refuses the same stage twice", () => {
    expect(() => appendStage("X/P1", "/P1", "P1")).toThrow();
  });
});

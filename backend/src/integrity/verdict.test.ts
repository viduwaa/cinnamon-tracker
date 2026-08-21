import { describe, expect, it } from "vitest";
import { computeVerdict } from "./verdict.js";

describe("computeVerdict", () => {
  it("returns TAMPERED whenever the chain is broken, anchored or not", () => {
    expect(computeVerdict({ chainValid: false, anchorConfirmed: false })).toBe("TAMPERED");
    expect(computeVerdict({ chainValid: false, anchorConfirmed: true })).toBe("TAMPERED");
  });

  it("returns PENDING when the chain is intact but not yet anchored", () => {
    expect(computeVerdict({ chainValid: true, anchorConfirmed: false })).toBe("PENDING");
  });

  it("returns AUTHENTIC only when both hold", () => {
    expect(computeVerdict({ chainValid: true, anchorConfirmed: true })).toBe("AUTHENTIC");
  });
});

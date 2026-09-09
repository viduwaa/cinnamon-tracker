/**
 * Short base-26 alphabetic codes used inside immutable numbering schemes
 * (farms.farmer_code, users.exporter_code). 1→A, 2→B … 26→Z, 27→AA …
 * Allocation lives with the owning feature; these are the shared codec.
 */
export function encodeAlphaCode(n: number): string {
  let code = "";
  let value = n;
  while (value > 0) {
    const rem = (value - 1) % 26;
    code = String.fromCharCode(65 + rem) + code;
    value = Math.floor((value - 1) / 26);
  }
  return code;
}

/** Inverse of encodeAlphaCode; unknown shapes decode to 0 (ignored). */
export function decodeAlphaCode(code: string): number {
  if (!/^[A-Z]+$/.test(code)) return 0;
  let value = 0;
  for (const ch of code) value = value * 26 + (ch.charCodeAt(0) - 64);
  return value;
}

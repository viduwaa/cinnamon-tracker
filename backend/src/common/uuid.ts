import { randomFillSync } from "node:crypto";
import { v4 as uuidv4, validate as uuidValidate, version as uuidVersion } from "uuid";

/**
 * UUIDv7 helpers. The app supplies client-generated UUIDv7 ids so offline
 * entities can be referenced before they sync; the server validates and
 * echoes them. We generate v7 server-side where needed (time-ordered).
 */

export function uuidv7(): string {
  // RFC 9562 v7: 48-bit unix ms timestamp | 4-bit version | 12-bit rand_a | 2-bit variant | 62-bit rand_b
  const now = Date.now();
  const bytes = new Uint8Array(16);
  // timestamp (48 bits)
  bytes[0] = (now / 2 ** 40) & 0xff;
  bytes[1] = (now / 2 ** 32) & 0xff;
  bytes[2] = (now / 2 ** 24) & 0xff;
  bytes[3] = (now / 2 ** 16) & 0xff;
  bytes[4] = (now / 2 ** 8) & 0xff;
  bytes[5] = now & 0xff;
  // random
  const rand = new Uint8Array(10);
  randomFillSync(rand);
  bytes.set(rand, 6);
  // version 7
  bytes[6] = (bytes[6] & 0x0f) | 0x70;
  // variant 10
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export function isUuidv7(value: string): boolean {
  return uuidValidate(value) && uuidVersion(value) === 7;
}

export function newIdempotencyKey(): string {
  return uuidv4();
}

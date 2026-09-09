import type { PoolClient } from "pg";
import { decodeAlphaCode, encodeAlphaCode } from "./codes";

/**
 * Allocate the exporter's immutable code (baked into lot numbers
 * `EX-SSS-YYYY-EXP-CODE`). Mirrors farms.farmer_code allocation: serialized
 * per-user via advisory lock, never recycled, max-decoded + 1.
 *
 * Called when an account gains the EXPORTER role (register / add-role) and
 * lazily by the first lot creation for exporters created before this change.
 */
export async function allocateExporterCode(
  client: PoolClient,
  userId: string,
): Promise<string> {
  await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
    `exporter_code:${userId}`,
  ]);
  const user = await client.query<{ exporter_code: string | null }>(
    "SELECT exporter_code FROM users WHERE id = $1 FOR UPDATE",
    [userId],
  );
  const existing = user.rows[0]?.exporter_code ?? null;
  if (existing) return existing;

  const codes = await client.query<{ exporter_code: string }>(
    "SELECT exporter_code FROM users WHERE exporter_code IS NOT NULL",
  );
  const next = codes.rows.reduce(
    (max, r) => Math.max(max, decodeAlphaCode(r.exporter_code)),
    0,
  );
  const code = encodeAlphaCode(next + 1);
  await client.query("UPDATE users SET exporter_code = $1 WHERE id = $2", [
    code,
    userId,
  ]);
  return code;
}

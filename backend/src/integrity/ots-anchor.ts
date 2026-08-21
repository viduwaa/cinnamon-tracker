/**
 * OpenTimestamps anchoring — the free third-party witness.
 *
 * We POST the digest (the daily Merkle root) to public calendar servers.
 * Each calendar commits to the digest and later aggregates commitments into
 * Bitcoin transactions. Cost: $0. No account, no wallet, no keys. Anyone can
 * independently verify an attestation without trusting us.
 *
 * M1 scope: stamp + store attestations (evidence of commitment). Full .ots
 * detached-proof upgrade/verify against Bitcoin is a documented follow-up;
 * the stored calendar attestations are the durable evidence until then.
 * Protocol: https://opentimestamps.org/
 */

export const PUBLIC_CALENDARS = [
  // Verified reachable 2026-08: the legacy alice/bob/finney.calendar.* hosts
  // are dead (no DNS) or have mismatched TLS certs. The *.btc.calendar.*
  // host is in the calendar's cert SAN and returns valid attestations.
  "https://bob.btc.calendar.opentimestamps.org",
];

export interface CalendarAttestation {
  calendarUrl: string;
  digestHex: string;
  attestationHex: string;
  receivedAt: string;
}

export class AnchorError extends Error {}

/**
 * Submit a 32-byte digest to the given calendars; returns every successful
 * attestation. Throws AnchorError only if ALL calendars fail — anchoring
 * succeeds if at least one independent calendar commits.
 */
export async function stampDigest(
  digestHex: string,
  calendars: string[] = PUBLIC_CALENDARS,
  fetchImpl: typeof fetch = fetch,
): Promise<CalendarAttestation[]> {
  if (!/^[0-9a-f]{64}$/i.test(digestHex)) {
    throw new AnchorError("stampDigest: digest must be 32-byte hex");
  }
  const body = Buffer.from(digestHex, "hex");
  const results: CalendarAttestation[] = [];
  const failures: string[] = [];

  for (const calendarUrl of calendars) {
    try {
      const response = await fetchImpl(`${calendarUrl}/digest`, {
        method: "POST",
        headers: { "Content-Type": "application/octet-stream" },
        body,
      });
      if (!response.ok) {
        failures.push(`${calendarUrl}: HTTP ${response.status}`);
        continue;
      }
      const attestationHex = Buffer.from(
        await response.arrayBuffer(),
      ).toString("hex");
      results.push({
        calendarUrl,
        digestHex: digestHex.toLowerCase(),
        attestationHex,
        receivedAt: new Date().toISOString(),
      });
    } catch (error) {
      failures.push(`${calendarUrl}: ${(error as Error).message}`);
    }
  }

  if (results.length === 0) {
    throw new AnchorError(
      `stampDigest: all calendars failed (${failures.join("; ")})`,
    );
  }
  return results;
}

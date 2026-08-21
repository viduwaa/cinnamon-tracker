import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Cron, CronExpression } from "@nestjs/schedule";
import { DatabaseService } from "../database/database.service";
import { merkleRoot, stampDigest, type CalendarAttestation } from "../integrity";
import { uuidv7 } from "../common/uuid";

/**
 * Nightly anchor job: collect all unanchored events, build a Merkle root
 * over their hashes, and submit it to OpenTimestamps public calendars.
 *
 * Free, account-less, Bitcoin-anchored. The stored calendar attestations are
 * the durable evidence; full .ots proof verification against Bitcoin is a
 * documented follow-up.
 */
@Injectable()
export class AnchorService {
  private readonly logger = new Logger(AnchorService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly config: ConfigService,
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async nightlyAnchor() {
    const enabled = this.config.get<string>("ANCHOR_CRON_ENABLED") === "true";
    if (!enabled) {
      this.logger.debug("Anchor cron disabled (ANCHOR_CRON_ENABLED != true)");
      return;
    }
    await this.runAnchor();
  }

  /** Manual trigger (admin endpoint) + cron entry point. */
  async runAnchor(): Promise<{
    anchored: number;
    merkle_root: string | null;
    attestations: CalendarAttestation[];
  }> {
    const events = await this.db.query<{ event_hash: string; id: string }>(
      "SELECT id, event_hash FROM batch_events WHERE anchored_at IS NULL ORDER BY created_at ASC, id ASC",
    );

    if (events.length === 0) {
      this.logger.log("No unanchored events; skipping");
      return { anchored: 0, merkle_root: null, attestations: [] };
    }

    const root = merkleRoot(events.map((e) => e.event_hash));
    const calendars = this.parseCalendars();

    let attestations: CalendarAttestation[] = [];
    let status = "FAILED";
    try {
      attestations = await stampDigest(root, calendars.length ? calendars : undefined);
      status = "CONFIRMED";
    } catch (err) {
      this.logger.error(`Anchoring failed: ${(err as Error).message}`);
    }

    const anchorId = uuidv7();
    await this.db.transaction(async (client) => {
      // Upsert: a previous FAILED attempt for the same event set produces the
      // same merkle_root; a retry must update that row, not collide on the
      // unique constraint.
      await client.query(
        `INSERT INTO chain_anchors
           (id, merkle_root, chain_head_hash, event_count, network, status)
         VALUES ($1, $2, $3, $4, 'BITCOIN_OTS', $5)
         ON CONFLICT (merkle_root) DO UPDATE
           SET status = EXCLUDED.status, event_count = EXCLUDED.event_count`,
        [anchorId, root, root, events.length, status],
      );

      if (status === "CONFIRMED") {
        const ids = events.map((e) => e.id);
        await client.query(
          "UPDATE batch_events SET anchored_at = now() WHERE id = ANY($1::uuid[])",
          [ids],
        );
        // Store the first calendar attestation hex for reference (OTS has no
        // single tx hash).
        await client.query(
          "UPDATE chain_anchors SET tx_hash = $1 WHERE merkle_root = $2",
          [attestations[0]?.attestationHex ?? null, root],
        );
      }
    });

    this.logger.log(
      `Anchored ${events.length} events, root=${root.slice(0, 16)}…, status=${status}`,
    );
    return { anchored: events.length, merkle_root: root, attestations };
  }

  private parseCalendars(): string[] {
    const raw = this.config.get<string>("OTS_CALENDARS") ?? "";
    return raw
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
  }
}

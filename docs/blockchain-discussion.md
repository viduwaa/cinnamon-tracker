# Blockchain — Separate Discussion Track

**Status:** DECIDED (2026-08-18) — hybrid: our own hash-chain integrity layer
+ free third-party witness (OpenTimestamps). See the Decision section below.

## Why this doesn't block the build

All integrity features in M1 work with **no blockchain at all**: the event
hash chain in Postgres already proves tamper-evidence, and QR verdicts simply
show `PENDING` until anchoring goes live. When a network is chosen, we
implement a single `AnchorService` interface:

```
nightly job: collect unanchored events → build Merkle root
           → submit one tx → backfill anchored_at on included events
```

Nothing else in the app or API changes.

Already in place for any option:

- `batch_events.event_hash` chain (see `schema.sql`)
- `chain_anchors` table with `network` enum (`POLYGON | VECHAIN | BITCOIN_OTS`)
- Verdict logic on the verify page (`AUTHENTIC` / `TAMPERED` / `PENDING`)

## Options on the table

| # | Option | Approx cost | Farmer-side UX | Proof strength | Ops burden |
|---|--------|-------------|----------------|----------------|------------|
| A | Daily Merkle root → Polygon PoS | < $2/mo at pilot scale | Zero (no wallets/keys) | Public tx proof, fast finality | Light (one hot wallet, server-held keys) |
| B | Per-event on-chain writes | Scales with volume × gas | Zero | Strongest granularity | Medium |
| C | Hyperledger Fabric / permissioned | Infra-heavy | Zero | "Consortium trust" only | Heavy (node ops) |
| D | OpenTimestamps (Bitcoin anchoring) | ~free | Zero | Public, hours-long finality | Minimal |

Preview recommendation for the discussion: **A**, with **D** as the
zero-budget fallback. **B** only if a partner demands per-batch on-chain
records. **C** rejected at current team size.

## Questions to answer in the discussion

1. **Who is the proof for?** EU importers/auditors (public chain helps) vs
   local trust (cheaper options fine)?
2. **Budget** for chain costs, and who owns/pays the anchor wallet?
3. **Anchor frequency** — nightly batching vs per-event (cost vs freshness)?
4. **Brand/regulatory angle** — does "verified on Polygon/Bitcoin" carry
   weight with buyers, or is a specific ecosystem (e.g. VeChain traceability
   partnerships) expected?
5. **Failure behavior** — if anchoring is down a week, is a `PENDING` verdict
   acceptable? (Architecture default: yes.)
6. Any future ambition for digital product passports / tokenization? (Affects
   chain choice; EUDR DPP work is ongoing in the EU.)

## Decision (2026-08-18)

**Question asked:** build our own blockchain, or use a free third-party one?

**Answer: both — but not in the way the question assumes.**

1. Building our own distributed blockchain (nodes, consensus) is **rejected**:
   months of effort, and a chain only we operate gives buyers no more reason
   to trust us than a database — a single-operator chain can always be
   rewritten by its operator. Trust requires an external witness.
2. What we build ourselves is the **integrity layer**: the hash-chained event
   ledger in Postgres (already in `schema.sql`, core logic implemented and
   tested in `backend/src/integrity/`). Free, fully under our control, and
   any silent DB edit breaks the chain and is detectable by recomputation.
3. The external witness is a **free third-party service**: OpenTimestamps —
   we submit the daily Merkle root to public calendar servers that aggregate
   digests into Bitcoin transactions. $0, no account, no wallet, no keys, and
   anyone can verify independently without trusting us.
4. The upgrade path stays open via the anchor seam: if pilots want a
   clickable smart-contract explorer link, we add a Polygon anchor (~$1/year)
   alongside — nothing else in the app changes.

Filled decision template:

- Network: OpenTimestamps public calendars (Bitcoin-anchored); Polygon optional add-on later
- Anchor frequency: nightly batch of all unanchored events
- Wallet custody: none required (OTS is account-less); a Polygon add-on would use one server-held hot wallet
- Monthly budget: $0 (≤ $1 with the Polygon add-on)
- Fallback if network unreachable: verdict shows `PENDING`; retry next cycle; hash-chain enforcement continues locally regardless

## Implementation status (2026-08-18) — WORKING END-TO-END

The hybrid is built and verified against a live database and the live
OpenTimestamps network:

1. **Hash chain** (`backend/src/integrity/hash-chain.ts`) — every event hash
   commits to its parent; tamper-evident. 9 unit tests.
2. **Merkle tree** (`merkle.ts`) — root over unanchored event hashes +
   inclusion proofs. 13 unit tests.
3. **OTS stamp client** (`ots-anchor.ts`) — submits the Merkle root to a
   public calendar. 4 unit tests.
4. **Verdict** (`verdict.ts`) — `AUTHENTIC` / `TAMPERED` / `PENDING`. 3 tests.
5. **AnchorService** (`backend/src/anchor/`) — nightly cron + manual trigger;
   builds the root, stamps it, backfills `anchored_at`.

**Verified live:** a farmer→collector batch produced 3 chained events; the
anchor job stamped the Merkle root and received a real 170-byte Bitcoin-anchored
attestation; the public `/verify/{batchNo}` endpoint returned **AUTHENTIC**
with all chain events verified.

### Calendar URL fix (important)
The legacy `alice/bob/finney.calendar.opentimestamps.org` hosts are dead
(no DNS) or have mismatched TLS certs. The working host is
`https://bob.btc.calendar.opentimestamps.org` (in the calendar's cert SAN,
returns valid attestations). This is now the default in `ots-anchor.ts` and
overridable via the `OTS_CALENDARS` env var.

### Bugs found & fixed during live testing
- **Read-after-commit**: `BatchesService.create` read the new row through the
  pool *inside* the transaction (invisible until commit) → moved the read
  after commit.
- **Timestamp normalization**: node-postgres returns `timestamptz` as `Date`
  objects; the hash was computed over the ISO string, so verify now
  normalizes `created_at` back to ISO before recomputing.
- **Anchor upsert**: a failed first attempt inserted a `chain_anchors` row
  with the same `merkle_root`; a retry collided on the unique constraint →
  changed to `ON CONFLICT (merkle_root) DO UPDATE`.

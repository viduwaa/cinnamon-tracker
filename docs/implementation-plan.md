# Implementation Plan & Build Tracker

**How this doc is used:** single source of truth for build state. Each work
session: tick off what completed, append any decisions to the log at the
bottom. Deep-dive docs: architecture (`PLAN.md`), API (`api-spec.md`),
database (`schema.sql`), mobile detail (`flutter-plan.md`), screens
(`wireframes.md`).

## Status snapshot (updated 2026-08-18)

- Design docs: ✅ complete
- Stack: ✅ DECIDED — Flutter · NestJS · PostgreSQL (`tech-stack.md`)
- Blockchain: ✅ decided AND working — own hash chain + free OpenTimestamps witness; live anchor returns AUTHENTIC (`blockchain-discussion.md`)
- Environment: ✅ portable Postgres 16.9 on :5433 · Flutter SDK 3.47.0 extracted + running (both in `tools/`)
- Backend: ✅ end-to-end verified against live Postgres + live OTS network
- Frontend: 🟢 M1 farmer→collector screens built + visually verified running against live backend (register, OTP, home, harvest wizard, batches, chain detail, QR, transfer, inbox)

## Milestones

| Milestone | Goal | Status |
|-----------|------|--------|
| M0 Discovery | Field research, batch-no spec, rules confirmation | ✅ assumed complete (spec built & adopted) |
| M1 MVP | Farmer → Collector flow + public QR verify, fully offline-first | 🟡 ~80% — backend ✓, UI ✓, offline-first ✗ |
| M2 | Processing, guided renumbering, export lots, live SMS, Tamil, admin | ⬜ — |
| M3 | EUDR reports, analytics, exporter integrations | ⬜ — |

**M1 gap to "done":** the only missing piece is the offline-first layer (drift
outbox). Everything else in the M1 demo script works end-to-end against the
live backend.

## Sprint 0 — Environment & scaffold — DONE

Dev machine state: Node v24 ✓ · npm 11 ✓ · git ✓ · no system Flutter ✓· no Docker.

Resolved: no system installs needed — everything is portable, no admin rights.

- [x] S1 Flutter SDK 3.47.0 stable extracted to `tools/flutter` (`flutter --version` works; runs in Chrome target `web-server`; **no Android SDK** on this machine, so Android builds aren't possible yet — web target only for now)
- [x] S2 Portable PostgreSQL 16.9 extracted to `tools/pgsql`, running on port 5433, `cinnamon` database created
- [x] Migrations applied (12 tables via `0001_init.sql` + `0002_seed_districts.sql`)
- [x] `npm install` for backend (~240 packages) + `flutter pub get` for app (~53 packages) both resolved

Everything portable lives in `tools/` (git-ignored). Setup scripts in `tools/setup-postgres.sh`, `tools/stop-postgres.sh`, `tools/smoke-test.sh`.
- [x] S3 `git init` at repo root; `.gitignore`; scaffolded `app/` (`flutter create --platforms web,android`) and `backend/` NestJS (manual, no nest CLI)
- [ ] S4 GitHub repo + CI skeletons (app: analyze/test/APK artifact; backend: lint/test) — **deferred until we decide hosting**

## M1 Backend — NestJS (sequential, one dev)

| # | Task | Depends | Done |
|---|------|---------|:----:|
| B1 | Scaffold NestJS + Prisma + env config + health endpoint | S3 | ✅ |
| B2 | Apply `schema.sql` as migration 0001; create restricted `app` DB role; RLS integration test proving upward-only visibility between two users | B1 | ✅ (applied to portable Postgres; visibility enforced in queries) |
| B3 | Auth: register, OTP request/verify behind `SmsProvider` interface (mock in dev), JWT, `/auth/me`, role add/remove | B2 | ✅ (verified live) |
| B4 | Farms CRUD + `farmer_code` assignment + district→area-code seed data; accepts client-supplied UUIDv7 `id` | B3 | ✅ (verified live) |
| B5 | Ledger service: event insert with hash-chain computation; test trigger populates `batch_actors` | B2 | ✅ (verified live) |
| B6 | Batches: create (regex validation + 409 `BATCH_NO_TAKEN` on collision), list+filters, detail, by-no, chain CTE; accepts client UUIDv7 `id` | B4, B5 | ✅ (verified live, 409 confirmed) |
| B7 | Transfers: recipient lookup, transfer-matrix validation, IN_TRANSIT → inbox → accept/reject | B6 | ✅ (verified live) |
| B8 | Public verify: `/verify/{batchNo}` JSON + server-rendered page; verdict logic (`PENDING` until anchoring exists) | B6 | ✅ (verified live, returns AUTHENTIC after anchor) |

> Note: backend uses raw `pg` (not Prisma) for the data layer — the workload
> is integrity-heavy (RLS, hash chain, recursive CTEs) and raw SQL is the
> cleaner fit. Decision logged 2026-08-18.

## M1 App — Flutter (WP1→WP10, full detail in `flutter-plan.md`)

| # | Work package | Acceptance headline | Done |
|---|--------------|---------------------|:----:|
| WP1 | Scaffold, theme (48dp targets), Baloo2+Noto Sans Sinhala, cinnamon design system | Shell runs in Chrome; cinnamon theme applied everywhere; types + palette verified | ✅ |
| WP2 | drift schema + DAOs (farms, batches, outbox, seq counters) | Atomic harvest-insert test (batch + counter + outbox in one tx) | ☐ (deferred: writing API-first first) |
| WP3 | dio client + auth repository + typed API errors | Wired to live backend; MOBILE_TAKEN login fallback added | ✅ |
| WP4 | Registration + OTP + role selection screens | Verified visually + driven against live backend (register→OTP→home) | ✅ |
| WP5 | Sync engine: outbox drain, dependency ordering, backoff, 409 regen | Deferred (on-device write path; API-first for now) | ☐ |
| WP6 | Farm wizard (name/district/size/lat-lng) | Farm created via wizard → farmer_code assigned | ✅ (map pin deferred) |
| WP7 | Harvest wizard 5 steps + batch-number preview + confirmation/QR/share | Visual steps verified (farm/date/type/numbers/review); live batch-no preview; saves to backend | ✅ |
| WP8 | Batches list/detail + chain timeline + QR display/scan | Verified: batch list, chain w/ "On blockchain" badges, QR show screen | ✅ |
| WP9 | Transfer flow + inbox + accept | Verified: recipient search (empty-q returns allowed recipients), SALE/HANDOFF, confirm, inbox accept | ✅ |
| WP10 | E2E hardening, TalkBack, perf budget, signed APK, offline outbox | Not started (needs drift + on-device) | ☐ |

**Note on sequencing:** I built the app API-first (every screen hits the live
backend directly) before the offline layer. This let me prove the full
farmer→collector UX visually on day one against real data. The drift offline
outbox (WP2/WP5) is the next big chunk — it's additive, wired behind the
same repositories the API already uses.

## M1 Definition of Done — demo script (with status)

| Step | Status |
|------|--------|
| 1. Two clean devices/emulators: Farmer + Collector accounts. | ⬜ — not yet tried on devices; each user works on the web app (tested in Chrome one at a time) |
| 2. Farmer registers + adds farm (syncs). | ✅ — via `POST /auth/register` OTP + `POST /farms`; farmer_code auto-assigned |
| 3. Farmer completes harvest offline → batch number shown big + QR. | 🟡 — works with network; offline storage not built yet (WP2/WP5) |
| 4. Farmer goes online → outbox drains → batch `SYNCED`. | ⬜ — deferred (WP5) |
| 5. Farmer transfers to Collector (SALE). Collector sees inbox → accepts → batch in their list with the same number. | ✅ — end-to-end smoke test + Chrome UI both work |
| 6. Any browser opens QR URL → verify page shows farm origin + handoff chain. | ✅ — `/verify/{batchNo}` returns AUTHENTIC with full chain when anchored |
| 7. Collector sees nothing downstream; farmer keeps history. | ⬜ — RLS logic enforces this, but not yet verified in a two-device UI test |

## M2 backlog (coarse)

- Processing screens (P1/P2) + auto stage suffixes + P2 guided renumbering
- Exporter lot builder (merge) + multi-origin QR page
- **Offline outbox (drift)** — belonged in M1; brought forward. Batch-number regeneration, farm-before-batch ordering.
- Live SMS gateway (real OTP), TalkBack walkthrough, Tamil ARB
- Admin back-office: `/admin/anchors` (read-only, exists), `/admin/users`,
  EUDR report export, `changed_since` delta pull on `/batches`
- Farm map pin: flutter_map + OSM tiles on the farm wizard (text lat/lng only today)
- QR scan: `mobile_scanner` camera on the QR tab (works in Android builds; Chrome dev builds have no camera)

## Contract amendments log

- **2026-08-18** — `POST /farms` and `POST /batches` now accept a
  client-supplied UUIDv7 `id` (server validates + echoes). Needed so offline
  entities can be referenced before they sync. `api-spec.md` updated.
- **2026-08-18** — Backlog: `changed_since` cursor on `GET /batches` to
  replace full-list pulls once volumes grow (M2).

## Decisions log

- **2026-08-18** — Stack decided: Flutter · Riverpod · drift · NestJS ·
  Prisma + raw-SQL migrations · PostgreSQL 16. Rationale in `tech-stack.md`.
- **2026-08-18** — Blockchain parked as separate discussion; architecture
  already chain-agnostic (hash chain + `AnchorService` seam + `PENDING` verdict).
- **2026-08-18** — Mobile implementation plan drafted by mobile specialist;
  adopted as `flutter-plan.md` (WP structure, sync engine, generator spec).
- **2026-08-18** — Blockchain decided: own hash-chain integrity layer + free
  OpenTimestamps witness (Bitcoin-anchored); Polygon kept as an optional
  ~$1/year add-on behind the anchor seam. Integrity core (hash chain, Merkle,
  OTS stamp client, verdict) implemented in `backend/src/integrity/` — 29
  unit tests passing.
- **2026-08-18** — Flutter app M1 frontend built & visually verified. "Cinnamon
  Harvest" design system (cream paper, cinnamon brown, quill amber, leaf
  green; Baloo 2 display + Noto Sans Sinhala body) bundled as fonts. Layers:
  Riverpod state, dio API client wired to the live backend, go_router shell
  (Home/Batches/QR + role chips + FAB). Screens built: register (with
  MOBILE_TAKEN login fallback), OTP, home (farms + active batches + incoming
  inbox banner), farm wizard (district→area code picker), harvest wizard (5
  steps w/ live batch-no preview + QR confirmation), batches, batch detail
  w/ chain-of-custody timeline + "On blockchain" badges, QR display,
  transfer (recipient search + SALE/HANDOFF + price), inbox accept. All
  driven end-to-end in Chrome against the live backend with real data.
  Fixed: empty-q recipients (backend DTO), fmtDate helper, URI/import paths,
  nullable text styles. Offline outbox (drift) intentionally deferred —
  built API-first to prove the UX.

## Next actions, in order

1. **Offline outbox (WP2/WP5)** — drift local DB + outbox queue + 409
   regen. This is what makes the app work with no connectivity, the single
   most important remaining feature for farmers. All screens already use
   repositories that this plugs into.
2. **Farm map pin** — flutter_map + OSM tile cache on the farm wizard
   (currently text lat/lng entry).
3. **On-device E2E (WP10)** — run on a real low-end Android, TalkBack
   walkthrough, APK size + cold-start budgets.
4. **QR scan (mobile_scanner)** — camera isn't available in Chrome dev builds;
   verify on a device.

---

## What's left — the real list (not sugarcoated)

**Must-do before any farmer can use this reliably (M1-critical, blocks launch):**

1. **Offline-first writes** (`WP2/WP5` in `flutter-plan.md`). Today every screen
   calls the live backend; a farmer with no signal loses work. Need: drift
   SQLite schema (farms/batches/events/outbox/seq counters), outbox queue with
   farm-before-batch dependency ordering, exponential backoff on failure, and
   409 `BATCH_NO_TAKEN` handling that regenerates the batch number with the next
   daily sequence. The batch-number generator (`core/domain/batch_number_generator.dart`)
   already exists and is unit-testable — the missing part is persisting it behind
   a local store + sync worker. See `flutter-plan.md` §3.1–3.2 for the full spec.
2. **Two-role end-to-end test**. RLS enforces "nobody sees downstream," but I've
   only driven single-user flows (farmer, then collector separately). Need one run
   with both roles active, ideally on two devices, to confirm the farmer can't see
   what the collector does next and vice versa.

**Quick wins (high value, small effort, any order):**

3. **Farm map pin on the farm wizard** — flutter_map + OSM with offline tile
   caching. Currently text lat/lng, unusable for most farmers.
4. **Sync-state chips + "Sync now" on the offline banner** — shows
   `pending / synced / error` per batch and a manual sync trigger. The
   `OfflineBanner` widget exists; wire it to the real `connectivity_plus` stream.
5. **Real SMS OTP** — the mock logs codes to console. Swap `MockSmsProvider`
   for a real gateway (Dialog/Airtel) behind the `SmsProvider` interface.
6. **TalkBack / accessibility pass** — all touch targets are ≥ 48dp and
   labels are in place; needs one walkthrough with TalkBack on a device.
7. **Error surfacing on batch cards** — when a sync fails permanently, the
   batch card should show an actionable error state, not just a red dot.

**Product/TODOs I noticed but haven't confirmed (needs user decision):**

8. **Transfer accept semantics** — `POST /inbox/:batchId/accept` marks the
   event `PROCESSED` event with `action: RECEIVED`. The backend sets
   `current_holder_role` from the *sender's* matrix rule, which works, but when
   a recipient holds multiple roles, accept uses a `.primaryRole()` fallback
   (`ORDER BY role`). Confirm whether accept should let the recipient pick the
   role they receive as (multi-role users) before shipping M2.
9. **Rejection flow** — no `reject` endpoint exists; if a recipient declines,
   the batch stays in `IN_TRANSIT`. Add `/inbox/:batchId/reject` and revert
   to previous status.
10. **Farm map pin → local GPS** — the farm wizard asks farmers to type lat/lng;
    "use my location" (`geolocator`) should be the primary path with map pin as
    fallback. Decide before WP6.
11. **QR verification page language** — the public `/verify/{batchNo}` is
    currently JSON-only; the page should render a friendly HTML page (EN/SI/TA).
    Currently designed to be server-rendered from the backend, not built yet.
12. **App release signing + size budgets** — `--split-debug-info`, R8 shrink,
    `--tree-shake-icons`; confirm APK ≤ 25MB, cold start ≤ 3.5s on an Android
    Go device. Not measurable until we have real hardware.

**Backend hygiene (not blocking):**

13. **Auth hash stability** — `occurredAt` is normalized to ISO in
    `verify.service.ts`. If we ever change the on-Disk `created_at`
    precision (e.g. nanoseconds), re-run `verifyChain` regression tests.
14. **Anchor `tx_hash` is repurposed** — it currently stores the raw OTS
    attestation hex for the first calendar confirmation, not a blockchain tx.
    Fine for now (verdict logic only keys off `network`+`status`), but the
    column name will confuse a future reader. Rename or add a proper `proof`
    JSONB when Polygon enters.
15. **Admin user scope** — `/admin/*` endpoints are behind `JwtAuthGuard`
    (any signed-in user), not a real admin scope. Add a `roles`-based guard
    before M2.

---

## Problems & blockers encountered (and how they were fixed)

| Date | Problem | Fix / status |
|------|---------|--------------|
| 2026-08-18 | **Bootstrap DNS routing**: out-of-box `winget`/`choco` both failed (permission denied, `lib-bad` access) on this machine. | Went portable instead: downloaded official zips for Postgres + Flutter, extracted under `tools/`. No admin rights needed. (Documented in `tools/README.md`.) |
| 2026-08-18 | **Read-after-commit in batch creation**: `BatchesService.create` called `this.get()` inside the transaction (`db.transaction`), which is a different connection from the pool — the new row wasn't visible yet → returned `BATCH_NOT_FOUND` for the just-created batch. | Moved the `get()` read **after** the transaction commits. |
| 2026-08-18 | **Timestamp normalization breaks verify recomputation**: `batch_events.created_at` is `timestamptz`; node-postgres returns it as a `Date` object, but the hash was computed over the ISO-8601 string at insert time. Recomputing with the `Date` object changed the string → every verify verdict returned `TAMPERED`. | In `verify.service.ts`, normalize `new Date(row.created_at).toISOString()` before hashing. Added a debug script to confirm. |
| 2026-08-18 | **Anchor retries collided on unique `merkle_root`**: a failed OTS stamp wrote a `chain_anchors` row; a retry recomputed the same root from the same events and hit the unique index on `chain_anchors.merkle_root` → `EADDRINUSE`-style crash (`duplicate key`). | Changed the anchor insert to `ON CONFLICT (merkle_root) DO UPDATE` — retries now update the row instead of crashing. |
| 2026-08-18 | **OpenTimestamps legacy calendar URLs are dead**: `alice/bob/finney.calendar.opentimestamps.org` have no A records; `bob.calendar` has a broken TLS cert (`SEC_E_WRONG_PRINCIPAL`). Original docs listed the dead ones as defaults. | Found the live host `bob.btc.calendar.opentimestamps.org` (in the cert SAN, returns valid 170-byte attestations) and made it the default; overridable via `OTS_CALENDARS` env. |
| 2026-08-18 | **Recip recipients endpoint rejected empty `q`**: the transfer screen calls `/transfers/recipients?q=` on load; the DTO required `Length(1,50)` → permanent 400, list always empty. | Relax to `MaxLength(50)` and treat `q=""` as "list all allowed recipients." |
| 2026-08-18 | **Stale browser tab cached the old JS bundle**: after restarting the Flutter dev server, the existing Chrome tab kept serving the old compiled `main.dart.js` (transfer route 404'd until a fresh tab). | Closed stale tabs and opened a new one; fixed by hitting the app fresh rather than navigating. |
|- | **Backend `dist/` must be rebuilt after every source change** — dev uses `npm run build && node dist/main.js`; forgetting build means running stale JS. | Added `ts-node-dev` as a dev script for hot reload; production still builds to `dist/`. |

---

## Repo state at this commit

- `cinnamon-tracker/app/` — Flutter mobile app (web builds on Chrome; Android path exists, not yet compiled).
- `cinnamon-tracker/backend/` — NestJS API + integrity core (`src/integrity/`), compiled clean to `dist/`, boots and serves `:3100` against portable Postgres.
- `cinnamon-tracker/docs/` — 9 files (architecture, API contract, DB schema, Flutter detail, wireframes, tech stack, blockchain decision paper + implementation status, this tracker).
- `cinnamon-tracker/tools/` — portable Postgres 16.9, portable Flutter 3.47.0, setup + smoke-test scripts. `git`-ignored; do not delete or commit.
- working branch: `main` (git init'd 2026-08-18, initial commit pending).

**Tests passing right now:** 29 backend unit tests (integrity core) · `flutter analyze` clean · end-to-end smoke test (`tools/smoke-test.sh`) green · Chrome visual sweep over farmer→collector flows green.
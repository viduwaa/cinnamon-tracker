# Cinnamon Trace — System Architecture Plan

**Project**: Blockchain-verified cinnamon batch traceability platform
**Region**: Sri Lanka (cinnamon farmers, processors, collectors, exporters)
**Status**: Draft v0.1 — for review and discussion

---

## 1. Vision and Strategic Context

A mobile-first supply chain platform where every cinnamon batch carries an
unbroken, verifiable record from farm plot to export container. Anyone holding
a batch — farmer, collector, processor, exporter — can trace **upward** to its
origin, and any outsider (buyer, certifier, EU importer) can scan a QR code to
verify authenticity and origin. The record is tamper-evident through a
blockchain-anchored hash chain.

### Why this matters (strategic context)

1. **EUDR compliance** — The EU Deforestation Regulation requires export lots
   to carry *geolocation coordinates of the plots of origin*. The farm plot
   mapping feature is not just nice UX; it is the compliance hook that makes
   this platform commercially valuable to exporters.
2. **Origin fraud** — Sri Lanka cinnamon commands a premium; adulteration and
   false origin claims are a real industry problem. An immutable chain of
   custody is the counter-claim.
3. **Farmer empowerment** — A farmer's batches become provably traceable,
   which supports price premiums and direct exporter relationships.

### Honest constraint (challenge to the assumption)

Blockchain verifies *what was recorded, when, and that it wasn't altered*.
It cannot verify that the farmer entered true data. Garbage in → verified
garbage. The system's real integrity value is (a) tamper-evidence after entry
and (b) chain of custody between roles. Physical verification (inspectors,
photos with GPS meta, random audits) is a complementary feature to consider —
not a blocker for MVP.

---

## 2. Actors and User Journeys

### Roles

| Code | Role | Can do |
|------|------|--------|
| FM | Farmer | Create harvest batches (only source of origin), sell/hand off to Collector or L1 Processor |
| P1 | Level-1 Processor | Receive from Farmer/Collector, process, renumber (guided), pass on |
| CL | Collector | Receive from Farmer, transport/aggregate, pass to any role **except Farmer**. **Cannot renumber.** |
| P2 | Level-2 Processor | Receive, process, renumber (guided), pass on |
| EX | Exporter | Receive, aggregate/merge lots, renumber, create export shipment |

One person can hold **multiple roles** (e.g., farmer who also processes).
Roles are selectable at registration and adjustable later.

### Primary journeys

1. **Farmer onboarding**: register (name, mobile, optional email, role) →
   OTP verify → add farm: drop pin on map (plus manual coordinate/text entry)
   → land size (acres/perches) → done.
2. **Harvest entry**: "I harvested today" → harvest date, tree count, weight
   (kg), harvest type (Trees `T` / Quills `Q`) → **system auto-generates batch
   number** → big confirmation screen with QR code + share button.
3. **Handoff**: pick batch → pick recipient role → find recipient by mobile
   number (or scan their QR) → confirm sell/hand-off → recipient sees it in
   "Incoming batches".
4. **Processing (L1/L2)**: receive batch → process (enter output weight, loss,
   method) → system suggests a new batch number → optionally edit within
   rules → parent link is mandatory and immutable.
5. **Export**: select multiple processed batches → merge into export lot →
   generate lot number → export QR with **multiple origin chains**.
6. **Verification**: anyone scans QR → public web page shows full origin chain
   (farm, dates, weights, every handoff, hash-verification status).

### Traceability rule (core invariant)

- Every role sees its batch **plus the full ancestry chain upward** (all the
  way to the farm).
- **No one sees downstream** — after you hand a batch off, you see your record
  and history, but not where it went next.
- Implemented as access control, not just UI hiding (see §6).

---

## 3. Functional Requirements (by module)

### 3.1 Identity & Roles
- Register: name (required), mobile (required, unique, login ID), email
  (optional), roles (one or many).
- Login: mobile + SMS OTP (Sinhala/Tamil/English). Fallback: password.
- Profile: add/remove roles at any time. Role changes do not affect existing
  batch records.
- Offline note: registration requires connectivity; everything after can be
  offline.

### 3.2 Farm Registry (Farmer)
- Multiple farms allowed. Per farm: name, land size + unit, plot location
  (map pin + manual lat/lng + text address), optional plot boundary polygon
  (for EUDR-grade geolocation in v2).
- A farm must exist before first harvest.

### 3.3 Harvest & Batch Creation (Farmer)
- Inputs: harvest date, tree count, weight (kg), harvest type `T` (trees) or
  `Q` (quills).
- System generates batch number per spec (§4). Farmer never types it.
- Batch is the **root of a chain**. Root numbers are immutable forever.
- Optional: photos of the harvest (GPS-tagged) — strengthens verification.

### 3.4 Handoff / Transfer (all roles)
- Transfer type: `SALE` or `HANDOFF` (same price, no payment processing in MVP).
- Recipient found by mobile number (primary) or QR scan (secondary).
- Transfer matrix (configurable — confirm with business):

| From \ To | Farmer | Collector | P1 | P2 | Exporter |
|-----------|:------:|:---------:|:--:|:--:|:--------:|
| Farmer    | – | ✓ | ✓ | ✗ | ✗ |
| Collector | ✗ | ✓ | ✓ | ✓ | ✓ |
| P1        | ✗ | ✓ | – | ✓ | ✓ |
| P2        | ✗ | ✓ | – | – | ✓ |
| Exporter  | ✗ | ✗ | ✗ | ✗ | – (terminal) |

- **Batch renumbering permission matrix** (core rule, confirmed interpretation):

| Node | Renumber allowed? | Rule |
|------|:-----------------:|------|
| Farmer (root) | No | Number is system-generated and immutable |
| Collector | **No** | Carries the number as received |
| L1 Processor | **No manual edit** | If same user as farmer: number unchanged, stage suffix auto-appended. If separate user: system generates a *new* number (user may choose a custom one that passes validation), parent link mandatory |
| L2 Processor | Yes (guided) | New number with mandatory parent link; origin untouched |
| Exporter | Yes (guided) | Merge lots; multiple parents; origin untouched |

> Note: your description had a contradiction ("batch number should be not
> editable" vs "updated for each process adding suitable additions"). The
> resolution above: **never manually editable; system auto-appends stage
> suffixes; only P2/Exporter get guided renumbering.** Confirm this at §9.

### 3.5 Processing Records (P1/P2)
- Inputs: output weight, process type (peeling, quilling, grading, grinding…),
  date, notes, photos.
- System records the event on the chain. Output weight becomes the batch's
  new weight.

### 3.6 Export Lot (Exporter)
- Merge 1..N batches → export lot with lot number, shipment date, destination
  country, buyer, container no.
- QR page for an export lot shows **all origin chains** merged.
- EUDR-ready export report: farm names, plot coordinates, harvest dates,
  chain hashes (v2 deliverable).

### 3.7 QR Verification Portal (public, no auth)
- URL: `https://verify.<domain>/<batch-no>`
- Content: chain timeline (each node: role, person/business name, date,
  location, weight, batch number), blockchain anchor status per node
  ("Verified on Polygon · tx 0x…"), overall verdict: **Authentic / Tampered /
  Unverified**.
- Language auto-detect: EN / SI / TA.

### 3.8 Notifications
- SMS to recipient mobile on incoming batch (needs SMS budget — see §9).
- In-app inbox as free fallback.

---

## 4. Batch Number Specification

Base format (per your example `AA-JULIANNO-2026-FARMER(A)-T`):

```
GM-172-01-2026-FM-A-T
│  │   │   │    │ │ └── Harvest type: T (trees) / Q (quills)
│  │   │   │    │ └──── Farmer code (e.g., A, B, … or 21)
│  │   │   │    └────── Role short code (FM, P1, CL, P2, EX)
│  │   │   └─────────── Year (2026)
│  │   └─────────────── Daily sequence (01, 02, …) per farm per day
│  └─────────────────── Julian day (172)
└────────────────────── Area code (2 letters, e.g., GM = Galle Matara belt,
                        KN = Kandy, MK = Matale)
```

**Example**: `GM-172-01-2026-FM-A-T`
→ Galle/Matara belt, Julian day 172, first harvest that day, year 2026,
farmer A, tree harvest.

### Stage suffixes (auto-appended, never editable)

| Stage | Resulting number |
|-------|------------------|
| Farmer harvest (root) | `GM-172-01-2026-FM-A-T` |
| P1 processing (any) | `GM-172-01-2026-FM-A-T/P1` |
| P2 processing | `GM-172-01-2026-FM-A-T/P1/P2` (or custom `GM-164-92-2026-P2-CODE`) |
| Exporter rename | `GM-172-01-2026-FM-A-T/P1/P2/EX` (or custom `…-EX-CODE`) |
| Export lot (merge) | `EX-001-2026-EXP-A` — old numbers of merged batches stay resolvable (aliases) |

Collector hand-offs leave the number **unchanged** (their event is recorded
in the chain, not the number).

### Implementation rules
- Root numbers are generated **on-device** (works offline): area code from
  farm's district + Julian day from device clock + per-farm daily counter +
  farmer code. Collision-safe because farmer code + day + seq is unique per
  farm, and one farmer = one primary device (two devices handled via
  per-device seq partition — see §9).
- The number is a *readable handle*; the **authoritative link is the database
  parent reference + hash chain**. Even if a number is visually modified,
  the lineage graph never changes.
- Display format: uppercase, hyphens, max ~28 chars. QR encodes only the
  batch number (plus verify URL prefix).

---

## 5. Domain Model

### Bounded contexts

```
┌────────────────────┐   ┌────────────────────┐   ┌─────────────────────┐
│ Identity & Roles   │   │  Farm Registry     │   │  Harvest & Batches  │
│ (users, roles,     │──▶│  (farms, plots,    │──▶│  (batches, events,  │
│  OTP auth)         │   │   locations)       │   │   numbers, QR)      │
└────────────────────┘   └────────────────────┘   └──────────┬──────────┘
                                                             │
┌────────────────────┐   ┌────────────────────┐   ┌──────────▼──────────┐
│ Verification       │◀──│  Anchoring         │◀──│  Transfers &        │
│ (public QR portal) │   │  (hash chain +     │   │  Processing          │
│                    │   │   blockchain root) │   │  (handoffs, events)  │
└────────────────────┘   └────────────────────┘   └─────────────────────┘
```

### Key entities

```
User            id, name, mobile (unique), email?, lang, created_at
UserRole        user_id, role (FM|P1|CL|P2|EX)          — multiple allowed
Farm            id, owner_user_id, name, size, size_unit, lat, lng,
                address_text, plot_polygon?, created_at
Batch           id, batch_no, farm_id (root), harvest_type (T|Q),
                harvest_date, tree_count, weight_kg, status
                (HARVESTED|PROCESSED|IN_TRANSIT|EXPORTED),
                root_batch_no, chain_head_hash
BatchEvent      id, batch_id, event_type (CREATED|PROCESSED|TRANSFERRED|
                MERGED|EXPORTED), actor_user_id, actor_role, from_user_id?,
                to_user_id?, payload (JSON: weights, method, notes),
                parent_event_hash, event_hash, anchored_tx?, created_at
MergeGroup      id, batch_id, merged_from_batch_ids[]   — export lots
Anchor          id, merkle_root, chain_head_hash, network, tx_hash,
                block_no, anchored_at
AuditLog        id, user_id, action, entity, before, after, ts
```

- **Batch numbers are a projection** of the event chain, not free-form state.
- `BatchEvent.event_hash = H(parent_event_hash | payload | actor | ts)` →
  a tamper-evident hash chain (the "mini-blockchain" inside Postgres).

---

## 6. Blockchain & Integrity Design

### Options (with trade-offs)

| Option | Cost/tx | Tamper evidence | Ops complexity | Verdict |
|--------|---------|-----------------|----------------|---------|
| **A. Hash-chain + periodic root anchor (recommended)** | ~$0.01/day (one anchor tx) | Strong: every event hash-chained; daily Merkle root on a public chain | Low | ✅ MVP |
| B. Full on-chain (every event as a contract call) | ~$0.01–0.10 per event × 1000s | Strong but gas burn grows with volume | Medium | Overkill at MVP scale |
| C. Private/permissioned ledger (Hyperledger Fabric) | Infra-heavy | Strong | High (node ops) | ❌ For a 5-person startup |
| D. Public timestamping (OpenTimestamps / Bitcoin) | ~free | Good (anchors to Bitcoin) | Low, but hours-long finality | Viable alt to A |

### Recommended design (Option A)

1. Every `BatchEvent` gets `event_hash` in Postgres (immutable chain).
2. Every night, a cron job builds a **Merkle root** over all events of the day
   (or the whole chain head) and submits **one transaction** to a low-fee
   public chain (Polygon PoS or VeChain) — a few cents per day.
3. The QR verification page recomputes event hashes from DB and compares with
   the anchored Merkle root → verdict: **Authentic** (hashes match & anchor
   exists) / **Tampered** (hash mismatch) / **Pending** (not yet anchored).
4. The anchor tx link is displayed on the verification page — public proof.

### Why this is honest and cheap
- Immutability: any silent DB edit breaks the hash chain instantly.
- Zero per-transaction cost on the farmer's side (no crypto wallets, no gas
  fees, no keys — farmers never interact with the blockchain directly).
- The anchor is *proof of existence + non-tampering*, which is exactly the
  claim the platform makes.

### Security & access control
- Upward-only visibility via RLS (Postgres row-level security):
  `user can read Batch iff user appears in the batch's event chain as actor
  or holder` + chain-walk query (recursive CTE over parent links).
- Roles & permission matrix enforced server-side (never trust the app).
- Audit log for every action; admin back-office with read-all (but cannot
  edit events).
- Farm data (coordinates) is public only via the QR page at the farmer's
  discretion (share exact plot vs. "Galle district" only) — important
  privacy point for farmers.

---

## 7. System Architecture

### Stack recommendation

| Layer | Choice | Why |
|-------|--------|-----|
| Mobile | **Flutter** | Single codebase (Android-first reality), good offline/SQLite story, fast UI iteration, works on low-end Android |
| Backend | **NestJS (Node/TS)** or **FastAPI (Python)** | Modular monolith, clear module boundaries (Identity, Farm, Batch, Transfer, Verify, Anchor). Laravel is a fine local-talent alternative |
| DB | **PostgreSQL + PostGIS** | Relational integrity + geospatial (plots, EUDR) |
| Sync | Local SQLite (drift) + outbox sync queue | Offline-first is non-negotiable (rural connectivity) |
| Maps | OpenStreetMap + MapLibre (offline tiles) | Free, offline caching; Google Maps as fallback |
| SMS | Local gateway (Dialog/Airtel APIs) or Twilio | OTP + incoming-batch alerts |
| Hosting | VPS (Sri Lanka or Singapore) or Cloudflare + Postgres managed | Cheap, low latency |
| QR portal | Server-rendered pages (or Next.js) at `verify.<domain>/<no>` | Public, read-only, SEO-able |

### Context diagram (C4-lite)

```
┌─────────────┐   HTTPS/offline-sync   ┌──────────────────────────────┐
│ Flutter App │◀──────────────────────▶│  Backend (modular monolith)  │
│ (farmer etc)│   local SQLite queue   │  Identity · Farm · Batch ·   │
└─────────────┘                        │  Transfer · Verify · Anchor  │
                                       └──────┬───────────────┬───────┘
                                              │               │
┌─────────────┐      ┌────────────────────┐  │  ┌────────────┐│  ┌───────────────┐
│ Public QR   │◀────▶│  PostgreSQL +      │◀─┘  │ SMS        │└─▶│ Public chain  │
│ portal page │      │  PostGIS + hash    │     │ gateway    │   │ (Polygon/… )  │
└─────────────┘      │  chain + Merkle    │     └────────────┘   └───────────────┘
                     └────────────────────┘
```

### Offline-first strategy (critical)
- All writes (harvest, transfer, process) go to local SQLite first, then a
  sync queue pushes to backend when online (idempotent, retried).
- Batch numbers generated on-device → no "must be online to harvest".
- Conflict handling: server rejects duplicates by unique batch_no + farm;
  client re-syncs and shows "pending" state until confirmed.
- Single-writer per farm assumed (one farmer, one phone). If a farmer uses
  two devices, partition the daily counter by device ID.

---

## 8. UX Design Principles (farmer-first)

### Navigation
- **Bottom navigation (4 tabs)**: `Home` · `+ Add Batch` (center, prominent)
  · `My Batches` · `QR` (scan/share).
- **Multi-role handling**: role chips on Home ("I'm acting as: Farmer / P1").
  One app, one login; the chosen role scopes what you see and can do. No
  separate logins per role — keeps it simple.
- Profile tab holds role management, farm management, settings, language
  switch (EN / SI / TA).

### Interface rules
- Large touch targets, big fonts, high-contrast, Sinhala-first labels.
- Number-only keypads for weight/tree count; default values where sensible.
- Every completed action ends in a **big confirmation screen**: batch number
  in huge text + QR code + "Share via WhatsApp" (WhatsApp is the de-facto
  comms channel for SL farmers).
- Guided wizard for harvest: 4 steps max, one question per screen.
- Errors in plain language ("Check your number") — no technical strings.
- Low-end device performance: no heavy animations, lazy image loading,
  offline-first caching of reference data (districts, areas).

### Sample harvest flow (happy path)
```
Home [+ Add Batch] → acting as Farmer → pick farm (map preview)
→ harvest date (default today) → tree count → weight (kg)
→ T or Q (big buttons with pictures: 🌳 Tree / 🪶 Quill)
→ CONFIRM → 🎉 Batch GM-172-01-2026-FM-A-T created
→ [Show QR] [Share] [Sell / Hand over now]
```

---

## 9. Open Questions & Assumptions (need your confirmation)

1. **Renumbering rules** — I resolved the contradiction as: *never manually
   editable; system auto-appends suffixes; only P2 and Exporter may renumber
   (guided, with mandatory parent link)*. Is that right? Specifically: should
   a *separate* L1 processor be allowed to choose a custom number, or only
   use the system-suggested one?
2. **Collector's downstream scope** — can a collector really hand to any role
   (including exporter)? Confirm the transfer matrix (§3.4).
3. **Splitting and merging** — farmers split batches when selling to multiple
   buyers; exporters merge many batches into one lot. I've assumed **both are
   required**. Confirmed?
4. **Blockchain choice** — Polygon-anchored Merkle root (recommended) vs.
   Bitcoin timestamping vs. something you already have in mind?
5. **Tech stack** — Flutter + NestJS/FastAPI + Postgres OK? Any existing
   stack preferences or team skills?
6. **SMS budget** — OTP + incoming-batch SMS costs real money per message;
   OK to start with in-app notifications + optional SMS?
7. **Payments** — is payment between roles (farmer↔collector) in scope, or
   record-only for MVP?
8. **Language** — Sinhala + English for MVP, Tamil in v1.1?
9. **Admin/back-office** — who operates it (you / a certifier / SLCB-style
   body), and should they get read-only or audit capabilities?
10. **Privacy** — confirm farmers are OK with plot coordinates being visible
    on the public QR page (or only on EUDR reports + private views).

---

## 10. Roadmap

| Milestone | Scope | Rough size |
|-----------|-------|------------|
| **M0 — Discovery** | Interview 5–10 real farmers/collectors/processors/exporters; confirm rules matrix; settle batch-no spec | 2–4 weeks |
| **M1 — MVP** | Registration + roles + OTP; farm profile (map pin); harvest → auto batch no + QR; batch list; transfer to Collector/L1; public verify page; hash chain + daily anchor; offline-first core; EN+SI | 8–12 weeks, 1–2 devs |
| **M2 — Full chain** | P1/P2 processing + guided renumbering; merging (export lots); collector flows; WhatsApp share; notifications; TA language; admin back-office | 6–8 weeks |
| **M3 — Enterprise** | EUDR export report (plot polygons, coordinates, chain evidence); exporter API/ERP integration; analytics dashboard (volumes, cycle times, loss rates); inspection/photo verification | ongoing |

---

## 11. ADR Summary (key decisions so far)

| # | Decision | Rationale | Alternative rejected |
|---|----------|-----------|----------------------|
| ADR-001 | Postgres as system of record + event hash chain | Relational integrity, geospatial, easy backups; hash chain gives tamper-evidence without blockchain ops cost | Full on-chain at MVP |
| ADR-002 | Daily Merkle-root anchoring to public chain | Cents/day, public proof, no farmer-side crypto | Per-event on-chain (cost), Fabric (ops) |
| ADR-003 | Offline-first mobile with device-generated batch numbers | Rural connectivity reality; farmers must never be blocked at harvest | Online-only (would fail in the field) |
| ADR-004 | Modular monolith backend | 1–2 dev team; clear boundaries; easy to split later | Microservices (premature) |
| ADR-005 | Batch number = readable handle; DB lineage = authority | Numbers stay short & human-friendly; renumbering can never break the chain | Encrypting full lineage into the number (unreadable, brittle) |
| ADR-006 | Upward-only visibility via RLS + chain-walk | Privacy & business rule enforced at DB level | UI-only hiding (bypassable) |

---

## 12. Risks

1. **Data integrity at the source** — false farmer entries are unverifiable by
   software alone → GPS-tagged photos, periodic audits, per-farm trust scores (v2).
2. **Low digital literacy / device quality** — mitigations: Sinhala-first,
   wizard flows, WhatsApp share, offline mode, USSD fallback for OTP.
3. **Adoption cold-start** — exporters must demand traceable batches to pull
   the chain; M0 should include at least one exporter partner.
4. **Batch number collisions across devices/farms** — mitigated by unique
   farmer code + daily counter + server-side uniqueness enforcement.
5. **SMS costs at scale** — cap OTP retries, batch SMS, opt for in-app where
   possible.
6. **Regulatory shifts (EUDR)** — plot-polygon capture is already in the
   model; keep it in scope for M3, don't gold-plate M1.

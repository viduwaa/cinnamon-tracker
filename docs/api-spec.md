# Cinnamon Trace — API Contract (v0.1)

Modular-monolith REST API. Base URL: `https://api.cinnamontrace.example/v1`.

**Conventions**

- Auth: `Authorization: Bearer <JWT>` issued by `/auth/verify`. All endpoints
  except `auth/*` and `verify/*` require it.
- Errors: `{ "error": { "code": "BATCH_NOT_FOUND", "message": "…" } }`.
  Validation failures use code `VALIDATION_ERROR` with field-level
  `details: [{ field, constraints[] }]`. Every response carries an
  `X-Request-Id` header for log correlation.
- Pagination: `?limit=20&offset=0` → `data[]` + `meta { total, limit, offset }`.
  (Exception: `GET /farms` returns a bare array — a farmer's farms are few.)
- Idempotency: mutating endpoints accept `Idempotency-Key`; retries with the
  same key + same body replay the stored 2xx response (header
  `Idempotency-Replayed: true`). Same key with a different body → `409
  IDEMPOTENCY_KEY_REUSED`. Failed executions are never stored, so the key
  stays retryable. Keys are scoped per user and expire after 72h.
- Client IDs: `POST /farms` and `POST /batches` include a client-generated
  UUIDv7 `id`, so the offline app can reference entities before they sync.
  The server validates format/uniqueness and echoes the id back. Replays of
  an already-used client id return the existing entity (natural
  idempotency) instead of an error.
- All timestamps ISO-8601 UTC.

**Role codes**: `FARMER`, `PROCESSOR_L1`, `COLLECTOR`, `PROCESSOR_L2`, `EXPORTER`.

---

## 1. Auth

| Method | Path | Purpose | Auth |
|--------|------|---------|:----:|
| POST | `/auth/register` | Create user + roles | – |
| POST | `/auth/otp/request` | Send OTP to mobile | – |
| POST | `/auth/otp/verify` | Verify OTP → JWT + user profile | – |
| GET  | `/auth/me` | Current profile + roles | ✓ |
| PUT  | `/auth/me` | Update name/email/lang | ✓ |
| POST | `/auth/me/roles` | Add role `{role}` | ✓ |
| DELETE | `/auth/me/roles/{role}` | Remove role | ✓ |

Register body:

```json
{
  "name": "Sunil Perera",
  "mobile": "+94771234567",
  "email": null,
  "roles": ["FARMER"],
  "preferred_lang": "si"
}
```

OTP verify response:

```json
{
  "token": "eyJhbGciOi…",
  "expires_in": 86400,
  "user": { "id": "…", "name": "…", "mobile": "…", "roles": ["FARMER"] }
}
```

## 2. Farms (FARMER only)

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/farms` | Create farm |
| GET  | `/farms` | My farms |
| GET  | `/farms/{id}` | Farm detail |
| PATCH | `/farms/{id}` | Update (size, location, name) |

Create body:

```json
{
  "id": "…UUIDv7, client-generated…",
  "name": "Home Garden",
  "area_code": "GM",
  "size_value": 1.5,
  "size_unit": "ACRE",
  "lat": 6.0329,
  "lng": 80.2168,
  "address_text": "Walpita, Galle",
  "location_public_level": "DISTRICT"
}
```

`farmer_code` and full `batch_no` prefix are returned by the server on farm
creation (e.g. `"farmer_code": "A"`).

## 3. Batches

| Method | Path | Purpose | Role |
|--------|------|---------|------|
| POST | `/batches` | Create root harvest batch | FARMER |
| GET  | `/batches` | My batches `?status=&role=&q=` | any |
| GET  | `/batches/{id}` | Batch + full upward event chain | chain member |
| GET  | `/batches/by-no/{batchNo}` | Resolve number → batch | chain member |
| GET  | `/batches/{id}/chain` | Ancestry chain (bottom-up) | chain member |

Create body (client-generated `batch_no` for offline support):

```json
{
  "id": "…UUIDv7, client-generated…",
  "farm_id": "…",
  "batch_no": "GM-172-01-2026-FM-A-T",
  "harvest_type": "T",
  "harvest_date": "2026-08-17",
  "tree_count": 45,
  "weight_kg": 120.5
}
```

Validation: `batch_no` must match
`^[A-Z]{2}-\d{3}-\d{2}-\d{4}-FM-[A-Z0-9]{1,4}-[TQ]$`, farm must belong to
caller, harvest_date ≤ today, weight > 0. Collision → `409`
(`BATCH_NO_TAKEN`) → client increments daily sequence and retries.

`GET /batches/{id}` response (trimmed):

```json
{
  "id": "…",
  "batch_no": "GM-172-01-2026-FM-A-T/P1",
  "status": "PROCESSED",
  "weight_kg": 98.0,
  "harvest_type": "T",
  "farm": { "name": "Home Garden", "area_code": "GM", "location": "Galle district" },
  "current_holder": { "name": "…", "role": "PROCESSOR_L1" },
  "current_holder_id": "…",
  "current_holder_role": "PROCESSOR_L1",
  "root_batch_no": "GM-172-01-2026-FM-A-T",
  "chain": [
    { "event_type": "CREATED",     "actor_role": "FARMER",       "at": "2026-08-17T06:30:00Z", "summary": "Harvested 120.5 kg, 45 trees" },
    { "event_type": "TRANSFERRED", "actor_role": "FARMER",       "at": "2026-08-18T09:00:00Z", "summary": "Sold to Nimal (PROCESSOR_L1)" },
    { "event_type": "PROCESSED",   "actor_role": "PROCESSOR_L1", "at": "2026-08-20T14:00:00Z", "summary": "Peeling & quilling → 98.0 kg" }
  ],
  "verification": { "status": "AUTHENTIC", "anchored_events": 3, "total_events": 3, "chain_head_hash": "sha256:…" }
}
```

## 4. Transfers

| Method | Path | Purpose |
|--------|------|---------|
| GET  | `/transfers/recipients?q=` | Lookup by mobile/prefix-name |
| POST | `/batches/{id}/transfer` | Confirm handoff |
| GET  | `/inbox` | Incoming batches (pending/accepted) |
| POST | `/inbox/{batchId}/accept` | Accept (default on SALE) |

Transfer matrix enforced server-side (see plan §3.4). Body:

```json
{
  "to_user_id": "…",
  "transfer_kind": "SALE",
  "price_lkr": 45000,
  "notes": "Paid cash on collection"
}
```

Rules: batch must be held by caller; recipient must hold a permitted role;
batch status must be `HARVESTED|RECEIVED|PROCESSED` (not `IN_TRANSIT`);
collector transfers never mutate `batch_no`.

**Recipient lookup privacy**: no directory enumeration. Queries shorter than
3 characters (names) or 6 digits (mobiles) return `[]`; matching is
prefix-only, capped at 10 rows; mobile numbers are masked
(`+947****4567`) unless the caller typed an exact full mobile number.
Optional `role=` narrows results to one recipient role; a role outside the
caller's transfer matrix also returns `[]`.

`GET /inbox` rows include `to_role` — the recipient role the transfer was
addressed to (`batches.current_holder_role`) — so multi-role clients can
scope their inbox to the acting role.

## 5. Processing (P1 / P2)

| Method | Path | Purpose |
|--------|------|---------|
| GET  | `/batches/{id}/process/suggest` | Suggested next batch number |
| POST | `/batches/{id}/process` | Record processing event |

Body:

```json
{
  "output_weight_kg": 98.0,
  "batch_no": null
}
```

Server behavior:

- `batch_no: null` → server appends stage suffix to current number
  (`…/P1`, `…/P1/P2`). **Never manually editable for P1** — a P1 request
  carrying `batch_no` is rejected with `400 P1_NOT_RENAMABLE`.
- P2 may supply a custom `batch_no`; it must match
  `^[A-Z]{2}-\d{3}-\d{2}-\d{4}-P2-[A-Z0-9]{1,4}$`. The parent link is created
  regardless — custom numbers never break lineage.
- Renumbering keeps every old number resolvable: the former number is stored
  in `batch_no_aliases` and the change is a first-class `RENAMED` ledger
  event. Printed QR labels with old numbers keep working.
- Same-user farmer+P1 case: number unchanged, `PROCESSED` event appended,
  `stage_suffix` updated.
- Re-processing under the same stage: number unchanged, only the `PROCESSED`
  event is appended.

## 6. Export lots (EXPORTER)

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/lots/preview` | Validate candidate batches for merge |
| POST | `/lots` | Create export lot (merge) + export in one step |
| GET  | `/lots` | My lots (with per-lot batch counts) |
| GET  | `/lots/{id}` | Lot + shipment details + all merged origin chains |

Body:

```json
{
  "batch_ids": ["…", "…"],
  "lot_no": "EX-001-2026-EXP-A",
  "shipment_date": "2026-09-10",
  "destination_country": "DE",
  "buyer_name": "Spice GmbH",
  "container_no": "MSKU1234567"
}
```

Rules: all candidates must be held by the exporter and be in
`HARVESTED|RECEIVED|PROCESSED`; `lot_no` must match
`^EX-\d{3}-\d{4}-EXP-[A-Z0-9]{1,4}$`; `container_no` (when present) must match
ISO 6346 `^[A-Z]{4}\d{7}$`. Creating the lot applies shipment fields and
`EXPORTED` immediately (one-step export — the exporter has no handover);
source batches move to `MERGED` with `MERGED_IN` events pointing at the lot.
The lot IS a batch row (its own hash-chained events, QR = verify URL), and its
verify page shows a multi-origin timeline plus an `origins[]` list (farm,
district, weight per source). `exporter_code` (the `EXP-A` part) is assigned
server-side when the account gains the EXPORTER role and returned in
`/auth/me` (`exporter_code`), so clients can generate lot numbers offline.
Duplicate `lot_no` → `409 LOT_NO_TAKEN`.

### 6.1 Exporter renumbering

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/batches/{id}/rename` | Exporter renumbers a held batch (pre-export) |

Body: `{"batch_no": null}` → appends `/EX` to the current number;
`{"batch_no": "GM-172-01-2026-EX-ACME"}` → custom number matching
`^[A-Z]{2}-\d{3}-\d{2}-\d{4}-EX-[A-Z0-9]{1,4}$`. Same alias/RENAMED-event
mechanics as the P2 rename; lot rows cannot be renamed.

## 7. QR

| Method | Path | Purpose |
|--------|------|---------|
| GET  | `/batches/{id}/qr` | PNG QR (encodes verify URL) |
| POST | `/qr/scan` | Decode scanned payload → batch summary |

QR payload: `https://verify.cinnamontrace.example/{batch_no}`.

## 8. Public verification (no auth)

Served at both `GET /v1/verify/{batchNo}` and the prefix-free
`GET /verify/{batchNo}` (the latter is what QR payloads encode:
`https://verify.<domain>/{batchNo}`). Identical JSON from both.

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/verify/{batchNo}` | Public chain + verdict (also served as HTML page) |

Response:

```json
{
  "batch_no": "EX-001-2026-EXP-A",
  "verdict": "AUTHENTIC",
  "anchors": [
    { "network": "POLYGON", "tx_hash": "0xabc…", "anchored_at": "2026-08-21T00:05:00Z", "status": "CONFIRMED" }
  ],
  "chain": [
    {
      "batch_no": "GM-172-01-2026-FM-A-T",
      "role": "FARMER",
      "actor": "Sunil Perera",
      "location": "Galle district",
      "at": "2026-08-17T06:30:00Z",
      "weight_kg": 120.5,
      "event_hash": "sha256:9f2c…",
      "verified": true
    }
  ]
}
```

Verdicts: `AUTHENTIC` (all hashes recompute & anchored) · `TAMPERED`
(hash mismatch) · `PENDING` (not yet anchored).

## 9. Admin (back-office, JWT with `admin` scope)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/admin/users` | User list/search |
| GET | `/admin/users/{id}` | User + batches |
| POST | `/admin/anchors/run` | Trigger anchor job manually |
| GET | `/admin/anchors` | Anchor history |
| GET | `/admin/audit?user_id=&entity=` | Audit log |

Admins are read-only over business data; no event mutation endpoint exists.
Access is gated by an explicit `ADMIN_USER_IDS` allowlist (env); an unset
list denies everyone.

## 10. Background jobs (not HTTP)

- **Nightly anchor** (00:00 local): collect unanchored events → Merkle root →
  insert `chain_anchors` → submit chain tx → confirm → backfill `anchored_at`.
- **SMS delivery queue**: OTP + incoming-batch notifications, with retry and
  daily budget cap.

## 11. Status codes

| Code | Meaning |
|------|---------|
| 200 / 201 | OK / created |
| 400 | Validation error — `VALIDATION_ERROR` with field-level `details[]` |
| 401 / 403 | Unauthenticated / role or visibility denied (`ADMIN_REQUIRED` on admin routes) |
| 404 | Not found (or hidden by visibility rules) |
| 409 | `BATCH_NO_TAKEN`, `LOT_NO_TAKEN`, `MOBILE_TAKEN`, `IDEMPOTENCY_KEY_REUSED`, `IDEMPOTENCY_IN_PROGRESS`, duplicate transfer, batch not in transferable state |
| 429 | `RATE_LIMITED` — global 120/min per IP; OTP requests capped at 5/15min |
| 503 | `DB_UNAVAILABLE` (Neon unreachable mid-transaction) or anchor network unreachable (verification degrades to `PENDING`) |

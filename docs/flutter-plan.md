# Cinnamon Trace — Flutter Implementation Plan

Target: Android-first (minSdk 23, Android Go / 2 GB RAM), Sinhala-first,
offline-first. Stack fixed: Flutter 3 stable (Dart 3), Riverpod 2, drift,
dio, flutter_map + OSM, qr_flutter + mobile_scanner,
flutter_localizations/intl.

Key architectural facts taken from the backend contract that shape everything below:

- All primary keys are UUIDv7 **supplied by the app** (per schema.sql header) —
  the client generates IDs for farms/batches locally, so outbox payloads can
  reference entities that haven't synced yet.
- `POST /batches` takes client-generated `batch_no`; collision = `409
  BATCH_NO_TAKEN` → client increments SEQ, regenerates, retries.
- `farmer_code` is assigned **by the server on farm creation** — therefore a
  brand-new farm created while offline cannot produce batch numbers until it
  has synced once. Registration/OTP already requires connectivity, so in
  practice the first farm syncs immediately; harvests on an *activated* farm
  are then fully offline. The harvest wizard gates on `farm.farmer_code !=
  null` (see WP6/WP7).
- All mutating calls accept `Idempotency-Key`; keys are generated once per
  outbox entry at enqueue time.

---

## 1. Project folder structure

Feature-first: each flow is a self-contained vertical (screens + state +
widgets), which maps 1:1 onto the work packages so a single developer never
edits across feature boundaries; shared machinery (db, api, sync) lives in
`core/`.

```
cinnamon_trace/
├── lib/
│   ├── main.dart                     # ProviderScope, env init, runApp
│   ├── app/
│   │   ├── cinnamon_trace_app.dart   # MaterialApp.router, locale resolution
│   │   ├── router.dart               # GoRouter config + auth/role redirects
│   │   └── theme.dart                # 48dp targets, text scale, palette
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart       # dio instance, base URL from --dart-define
│   │   │   ├── auth_interceptor.dart # JWT attach, 401 handling
│   │   │   ├── api_exception.dart    # typed errors: ApiError(code, status, details)
│   │   │   └── endpoints/            # auth_api.dart, farms_api.dart, batches_api.dart,
│   │   │                             # transfers_api.dart, qr_api.dart (thin dio wrappers)
│   │   ├── db/
│   │   │   ├── app_database.dart     # drift DB class (all tables)
│   │   │   ├── tables.dart           # table definitions
│   │   │   └── connection.dart       # NativeDatabase + path_provider
│   │   ├── sync/
│   │   │   ├── outbox_repository.dart
│   │   │   ├── sync_worker.dart      # push loop, retry/backoff, 409 handling
│   │   │   ├── pull_service.dart     # GET /batches, GET /inbox upserts
│   │   │   └── connectivity_monitor.dart
│   │   ├── domain/
│   │   │   ├── batch_number_generator.dart  # pure, no imports beyond intl
│   │   │   ├── transfer_matrix.dart
│   │   │   ├── role.dart             # enum RoleCode { farmer, processorL1, ... }
│   │   │   └── models/               # freezed DTOs mirroring api-spec JSON
│   │   ├── auth/
│   │   │   ├── auth_repository.dart  # token in flutter_secure_storage
│   │   │   └── auth_state.dart
│   │   ├── providers.dart            # db, api, auth, sync, activeRole providers
│   │   └── widgets/                  # ct_button.dart, ct_card.dart, offline_banner.dart,
│   │                                 # big_confirmation.dart, status_chip.dart, pin_picker.dart
│   ├── features/
│   │   ├── auth/                     # registration + OTP (screens, otp_controller.dart)
│   │   ├── shell/                    # scaffold: role chips header, bottom nav, FAB
│   │   ├── home/                     # per-role home variants (farmer_home.dart, holder_home.dart)
│   │   ├── farms/                    # farm wizard, farm list, map picker
│   │   ├── harvest/                  # 5-step wizard + confirmation
│   │   ├── batches/                  # list, detail, chain_timeline.dart
│   │   ├── transfer/                 # recipient search, confirm transfer
│   │   ├── inbox/                    # incoming transfers, accept
│   │   └── qr/                       # qr_display.dart, qr_scan_screen.dart, scan_resolver.dart
│   └── l10n/
│       ├── app_si.arb  app_en.arb    # Sinhala source-of-truth keys
│       └── l10n.yaml
├── assets/fonts/NotoSansSinhala-Regular.ttf, NotoSansSinhala-Bold.ttf
├── test/                             # mirrors lib/ structure
├── integration_test/
│   └── farmer_to_collector_test.dart
└── .github/workflows/ci.yml
```

---

## 2. Package list

Pin the exact version in `pubspec.yaml` (not a caret range) after resolving
once at scaffold, so `pubspec.lock` and CI are reproducible. Majors below are
the guidance.

| Package | Purpose | Pinned-major guidance |
|---|---|---|
| `flutter_riverpod` | State management (Notifier/AsyncNotifier, ProviderScope) | ^2.5 (Riverpod 2, **not** 3 — decided) |
| `drift` | SQLite persistence, typed tables, transactions | ^2.x latest stable |
| `dio` | HTTP client, interceptors | ^5.x |
| `go_router` | Declarative navigation, shell routes, redirects, deep links | ^14.x (current major at scaffold) |
| `flutter_map` | OSM map for farm pin | ^7.x (verify Flutter 3 compat at scaffold) |
| `latlong2` | LatLng for flutter_map (transitive requirement) | ^0.9.x |
| `qr_flutter` | Render batch QR codes | ^4.1 |
| `mobile_scanner` | Camera QR scanning (ML Kit) | ^5.x/6.x latest stable |
| `flutter_localizations` (SDK) | Sinhala/English material + intl plumbing | match Flutter SDK |
| `intl` | Date/number formatting for `si`/`en` | version forced by flutter_localizations (0.19.x line) |
| `connectivity_plus` | Online/offline detection stream | ^6.x |
| `flutter_secure_storage` | JWT storage (EncryptedSharedPreferences) | ^9.x |
| `uuid` | UUIDv7 client IDs + v4 idempotency keys | ^4.x |
| `share_plus` | WhatsApp/share sheet for verify URL + batch no | latest major at scaffold (^10.x line) |
| `url_launcher` | `whatsapp://send?text=` direct share, open verify page | ^6.x |
| `path_provider` | DB + tile cache paths | ^2.x |
| `freezed_annotation` + `json_annotation` | Immutable DTOs + JSON mapping for api-spec payloads | ^2.5 / ^4.9 |

**Dev dependencies**

| Package | Purpose |
|---|---|
| `drift_dev` + `build_runner` | drift table codegen |
| `freezed` + `json_serializable` | DTO codegen |
| `flutter_lints` (^4.x or latest major) | baseline lints; extend with `always_use_package_imports`, `unawaited_futures`, `avoid_print` |
| `mocktail` | Mocking dio/repos in unit+widget tests |
| `flutter_test`, `integration_test` (SDK) | Widget + on-device integration tests |
| `network_image_mock` (or HttpOverrides fixture) | Deterministic widget tests |

Fonts: `NotoSansSinhala` Regular + Bold only (two weights — keep APK small),
declared under `flutter: fonts:`.

---

## 3. Data layer design

### 3.1 drift tables (`lib/core/db/tables.dart`)

```dart
class Users extends Table {                 // /auth/me cache
  TextColumn get id => text()();            // UUIDv7 from server
  TextColumn get name => text()();
  TextColumn get mobile => text()();
  TextColumn get email => text().nullable()();
  TextColumn get preferredLang => text().withDefault(const Constant('si'))();
}

class UserRoles extends Table {
  TextColumn get userId => text()();
  TextColumn get role => text()();          // FARMER | PROCESSOR_L1 | COLLECTOR | PROCESSOR_L2 | EXPORTER
  @override List<Set<Column>> get primaryKey => {userId, role};
}

class Farms extends Table {
  TextColumn get id => text()();            // UUIDv7, client-generated
  TextColumn get name => text()();
  TextColumn get areaCode => text()();      // 'GM','KN','MK'…
  TextColumn get farmerCode => text().nullable()(); // null until server confirms farm
  RealColumn get sizeValue => real()();
  TextColumn get sizeUnit => text().withDefault(const Constant('ACRE'))(); // ACRE|PERCH|HECTARE
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  TextColumn get addressText => text().nullable()();
  TextColumn get locationPublicLevel => text().withDefault(const Constant('DISTRICT'))();
  TextColumn get syncState => text().withDefault(const Constant('LOCAL'))(); // LOCAL|SYNCED|ERROR
  DateTimeColumn get createdAt => dateTime()();
}

class Batches extends Table {
  TextColumn get id => text()();            // UUIDv7 client-generated
  TextColumn get batchNo => text()();       // unique locally too (catches same-device dupes)
  TextColumn get farmId => text()();
  TextColumn get harvestType => text()();   // T|Q
  TextColumn get harvestDate => text()();   // yyyy-MM-dd (kept as text: API sends date string)
  IntColumn  get treeCount => integer()();
  RealColumn get weightKg => real()();
  TextColumn get status => text().withDefault(const Constant('HARVESTED'))(); // per state machine
  TextColumn get currentHolderId => text().nullable()();
  TextColumn get currentHolderRole => text().nullable()();
  TextColumn get rootBatchNo => text()();
  TextColumn get stageSuffix => text().withDefault(const Constant(''))();
  TextColumn get syncState => text().withDefault(const Constant('LOCAL'))(); // LOCAL|SYNCED|CONFLICT|ERROR
  DateTimeColumn get createdAt => dateTime()();
}

class BatchEventsCache extends Table {      // upward chain[] from GET /batches/{id}
  TextColumn get id => text()();
  TextColumn get batchId => text()();
  TextColumn get eventType => text()();     // CREATED|TRANSFERRED|PROCESSED|MERGED_IN|EXPORTED|ANCHORED
  TextColumn get actorRole => text()();
  TextColumn get summary => text()();       // server-rendered summary string
  TextColumn get at => text()();            // ISO-8601
  TextColumn get eventHash => text().nullable()();
  TextColumn get anchoredAt => text().nullable()();
}

class InboxItems extends Table {            // GET /inbox cache
  TextColumn get transferId => text()();
  TextColumn get batchId => text()();
  TextColumn get batchNo => text()();
  TextColumn get fromUserId => text()();
  TextColumn get fromName => text()();
  TextColumn get fromRole => text()();
  RealColumn get weightKg => real()();
  TextColumn get kind => text()();          // SALE|HANDOFF
  TextColumn get status => text()();        // PENDING|ACCEPTED
  TextColumn get receivedAt => text()();
}

class Outbox extends Table {
  IntColumn  get id => integer().autoIncrement()();
  TextColumn get entityType => text()();    // farm | batch | transfer | accept
  TextColumn get entityId => text()();      // local UUIDv7 of the entity
  TextColumn get method => text()();        // POST
  TextColumn get path => text()();          // /farms, /batches, /batches/{id}/transfer, /inbox/{id}/accept
  TextColumn get payloadJson => text()();
  TextColumn get idempotencyKey => text()(); // uuid v4, stable per entry (rotated on 409 regen)
  IntColumn  get dependsOn => integer().nullable()(); // outbox.id that must be SYNCED first
  TextColumn get status => text().withDefault(const Constant('PENDING'))(); // PENDING|IN_FLIGHT|SYNCED|FAILED_PERMANENT
  IntColumn  get attempts => integer().withDefault(const Constant(0))();
  IntColumn  get regenCount => integer().withDefault(const Constant(0))(); // 409 regenerations
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  TextColumn get lastErrorCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class SeqCounters extends Table {           // per-farm daily SEQ
  TextColumn get farmId => text()();
  TextColumn get dayKey => text()();        // 'yyyy-ddd' e.g. '2026-172'
  IntColumn  get lastSeq => integer()();
  @override List<Set<Column>> get primaryKey => {farmId, dayKey};
}

class MetaKv extends Table {                // activeRole, lastPullAt, flags
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override Set<Column> get primaryKey => {key};
}
```

JWT is **not** in drift — it lives in `flutter_secure_storage`. drift DB opens
lazily (`NativeDatabase` on first repo use, not in `main()`), which matters
for cold-start on 2 GB devices.

### 3.2 Outbox sync engine

**Enqueue (write path).** Every mutation is a local drift transaction that
(a) inserts/updates the entity row with `syncState = LOCAL` and (b) appends
an `Outbox` row with a fresh `idempotencyKey` (uuid v4) and the exact JSON
body from api-spec. For a harvest, one transaction inserts `Batches` + bumps
`SeqCounters` + appends `Outbox` — so the batch number, the counter, and the
queue can never diverge.

**Dependencies / ordering.** `Outbox.dependsOn` points at the prerequisite
entry: a batch entry carries the `outbox.id` of its farm's entry (if that
farm entry hasn't reached `SYNCED` yet). Transfers depend on their batch's
entry. Worker selection query:

```sql
SELECT * FROM outbox
WHERE status = 'PENDING'
  AND (next_retry_at IS NULL OR next_retry_at <= :now)
  AND (depends_on IS NULL
       OR depends_on IN (SELECT id FROM outbox WHERE status = 'SYNCED'))
ORDER BY id ASC LIMIT 1;
```

Because farms are enqueued before their batches and `ORDER BY id` preserves
insertion order, a farm always lands on the server before any batch that
references it; a batch whose farm is still pending is simply skipped until
the farm syncs (the loop re-runs after each success, so it drains naturally).

**Worker.** `SyncWorker` is a plain class owned by a Riverpod provider (no
background isolate needed in M1; it runs while the app is foregrounded):

```dart
class SyncWorker {
  Future<void> drain();                    // loop pick→send until queue empty/blocked
  Future<PushResult> _send(OutboxRow row); // one request
  Future<void> _handle409BatchNoTaken(OutboxRow row);
}
```

Triggers for `drain()`: app start (after auth restored), `connectivity_plus`
stream flipping to online, app resumed from background, after any new
enqueue, every 15 min while online, and a manual "Sync now" tap on the
offline banner. A single-flight guard (`_draining` flag) prevents concurrent
drains.

**Retry/backoff.** Network errors and 5xx: `attempts++`, `next_retry_at =
now + delay`, delay = `30s * 4^(attempts-1)` capped at 30 min, ±20% jitter.
4xx handling by code:

- `409 BATCH_NO_TAKEN` on a batch entry → regeneration path below (not
  counted as failure).
- `409` duplicate transfer / bad state, `400`, `403`, `404` → `status =
  FAILED_PERMANENT`, write `lastErrorCode`, set entity `syncState = ERROR`;
  UI shows a tappable "problem with this item — open to fix" on the batch
  card. These are never silently retried.
- `401` → pause drain, raise auth event → router redirects to OTP login;
  local data untouched. After re-login, drain resumes.

**Success.** `status = SYNCED`; entity `syncState = SYNCED`; for farm
entries, parse `farmer_code` from the `POST /farms` response and write it to
`Farms.farmerCode` (this is what unlocks harvests for that farm). Then
immediately pick the next row (dependent batches unblock).

**409 collision resolution (batch number).**

1. Server returns `409 BATCH_NO_TAKEN` for `GM-172-01-2026-FM-A-T`.
2. In one drift transaction: read `SeqCounters(farmId, dayKey)`; `newSeq =
   max(counter.lastSeq, failedSeq) + 1`; upsert counter; regenerate
   `batch_no` via `generateBatchNo(...)`; update `Batches.batchNo` (safe
   while `syncState != SYNCED` — number is only immutable after server
   acceptance) and `Batches.rootBatchNo`; rewrite `Outbox.payloadJson` with
   the new number; **rotate `idempotencyKey`** (payload changed — avoids any
   server-side key→response cache ambiguity); `regenCount++`; `nextRetryAt =
   now`.
3. Loop repeats. Cap: `regenCount > 5` → `FAILED_PERMANENT` (cannot happen
   with one device per farmer; the cap exists so a bug can't spin forever).
   The confirmation screen for a pending batch re-reads `Batches.batchNo`, so
   the farmer always sees the final number.

The local unique index on `Batches.batchNo` plus the transactional counter
prevents same-device collisions entirely; 409s can only come from another
device/account, which is the rare case this machinery exists for.

**Pull path (`PullService`).** Runs when online: `GET
/batches?role=<activeRole>` (paginate `limit=20` until exhausted), upsert
into `Batches` by `id` (server rows win over `SYNCED` local rows; never
clobber `LOCAL` rows still in outbox); `GET /inbox` upsert into
`InboxItems`. Chain arrays are pulled on demand (`GET /batches/{id}` when
detail opens) into `BatchEventsCache`. The spec has no `changed_since`
cursor — noted as a backend improvement request; until then, full-list pull
on resume is acceptable at M1 volumes.

### 3.3 On-device batch-number generator (`lib/core/domain/batch_number_generator.dart`)

Pure, synchronous, zero dependencies beyond `DateTime` — trivially
unit-testable:

```dart
enum HarvestType { trees, quills }  // serializes to 'T' / 'Q'

/// 1-based day-of-year.
int julianDay(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final jan1 = DateTime.utc(date.year, 1, 1);
  return d.difference(jan1).inDays + 1;
}

/// Returns e.g. 'GM-172-01-2026-FM-A-T'.
/// Throws [ArgumentError] on invalid inputs, [StateError] if seq > 99.
String generateBatchNo({
  required String areaCode,      // exactly 2 chars A-Z
  required DateTime harvestDate, // date part used; time ignored
  required int seq,              // 1..99
  required String farmerCode,    // 1..4 chars A-Z0-9, from server
  required HarvestType type,
}) {
  final area = areaCode.toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(area)) throw ArgumentError('areaCode');
  final fc = farmerCode.toUpperCase();
  if (!RegExp(r'^[A-Z0-9]{1,4}$').hasMatch(fc)) throw ArgumentError('farmerCode');
  if (seq < 1 || seq > 99) throw StateError('seq out of range: $seq');
  final jd = julianDay(harvestDate).toString().padLeft(3, '0');
  final s = seq.toString().padLeft(2, '0');
  return '$area-$jd-$s-${harvestDate.year}-FM-$fc-${type == HarvestType.trees ? 'T' : 'Q'}';
}

final batchNoPattern =
    RegExp(r'^[A-Z]{2}-\d{3}-\d{2}-\d{4}-FM-[A-Z0-9]{1,4}-[TQ]$'); // mirrors server validation
bool isValidBatchNo(String s) => batchNoPattern.hasMatch(s);
```

`dayKey` for `SeqCounters` is `'${year}-${jd}'`. Year and Julian day derive
from the **entered harvest date** (defaults to today), and the SEQ counter is
keyed by `(farmId, dayKey)` — per farm, per day, exactly per spec.

**Generator unit-test cases (required):**

1. Canonical example: area `GM`, date 2026-06-21 (day 172), seq 1, farmer
   `A`, trees → `GM-172-01-2026-FM-A-T`.
2. Seq padding: seq 3 → `-03-`; seq 12 → `-12-`.
3. Julian day boundaries: Jan 1 → `001`; Dec 31 non-leap (2026) → `365`;
   Dec 31 leap (2028) → `366`; Feb 29 2028 → `060`.
4. Quills type → trailing `-Q`.
5. Numeric farmer code: `21` → `…-FM-21-T`; 4-char code `A1B2` accepted.
6. Lowercase inputs `gm`/`a` normalized to uppercase.
7. Throws on: 1- or 3-char area code; empty or 5-char farmer code; seq 0;
   seq 100.
8. Time-of-day ignored: same date at 00:01 and 23:59 → identical output.
9. Every generated sample passes `isValidBatchNo` (round-trip against the
   server regex).
10. Year in output equals harvest-date year (2027 date → `-2027-`).

---

## 4. Feature breakdown per flow

Notation: **State** = Riverpod providers held for the flow; **Offline** =
behavior with no connectivity.

### 4.1 Auth / OTP (`features/auth/`)

- **Screens**: `register_screen.dart` (name, mobile with `+94` prefix fixed,
  optional email, multi-select role cards with Sinhala labels + icons),
  `otp_screen.dart` (6 boxes, numeric keypad, resend countdown), reused for
  login (mobile only → OTP).
- **State**: `authStateProvider` (Notifier → `unauthenticated |
  otpSent(mobile) | authenticated(user)`); registration form held in local
  `StateProvider`, not persisted.
- **API**: `POST /auth/register` → `POST /auth/otp/request` → `POST
  /auth/otp/verify` → JWT to secure storage, user + roles into drift, `GET
  /auth/me` on resume to refresh roles.
- **Offline**: registration requires network — screen shows the offline
  banner and the Continue button is disabled with "අන්තර්ජාලය අවශ්‍යයි"
  (plain-language). After first login, a 401 never wipes drift: user is sent
  to OTP login and local data survives.

### 4.2 Shell: role switching + bottom nav + FAB (`features/shell/`)

- **Screen**: `app_shell.dart` — header (name, gear → profile), role chip row
  (visible only when `roles.length > 1`), 3-tab `NavigationBar` (Home ·
  Batches · QR), center FAB "＋ New Batch".
- **State**: `activeRoleProvider` (StateProvider<RoleCode>, persisted in
  `MetaKv` so it survives restart); `inboxCountProvider` (stream over
  `InboxItems` where status PENDING) drives the "📥 N batches waiting" Home
  banner.
- **API**: none directly.
- **Offline**: fully functional; chip switching is pure local state.
- **Scoping**: FAB visible only when `activeRole == FARMER` and a farm with
  `farmerCode != null` exists (otherwise FAB tap routes to farm wizard with
  explanation). Home tab renders `FarmerHome` vs `HolderHome` by role.
  Batches tab query and transfer recipient matrix row both read
  `activeRoleProvider`. Server remains the authority (RLS) — app scoping only
  shapes the UI.

### 4.3 Farm wizard (`features/farms/`)

- **Screens**: `farm_wizard.dart` — Step 1 name; Step 2 district picker
  (dropdown of 25 districts → `area_code` from bundled lookup table
  `districts.json`); Step 3 location: `flutter_map` with OSM tiles, "use my
  location" (`geolocator` optional; manual fallback is primary — big
  draggable pin + lat/lng text fields with numeric keypad); Step 4 size +
  unit (ACRE/PERCH/HECTARE, decimal keypad) + privacy level (default
  DISTRICT); review → save.
- **State**: wizard draft in a local Notifier; `farmsProvider` = stream over
  `Farms` table.
- **API**: `POST /farms` (via outbox; response carries `farmer_code`), `GET
  /farms` pull on resume.
- **Offline**: farm saves locally instantly (`syncState = LOCAL`, outbox
  queued). While `farmerCode == null` the farm card shows "waiting for first
  sync" and harvest is disabled for that farm — the only harvest gate in the
  app. Map works offline via cached tiles (district bounding-box prefetch in
  WP6; pin placement never needs network).

### 4.4 Harvest wizard (`features/harvest/`)

- **Screens**: 5 one-question steps per wireframe — farm picker (with map
  preview) → date (default today, `showDatePicker`, capped at today) → type
  (two huge image cards T/Q) → numbers (tree count: `TextInputType.number`;
  weight kg: `numberWithOptions(decimal: true)`) → review showing the
  **computed batch number live** → confirm.
- **State**: `HarvestDraft` Notifier (farmId, date, type, treeCount,
  weightKg). On confirm, one drift transaction: allocate SEQ (`SeqCounters`
  upsert), `generateBatchNo`, insert `Batches` (status `HARVESTED`, holder =
  self, `root_batch_no` = number), enqueue outbox with `dependsOn` = farm's
  outbox id if farm not yet SYNCED. Then push route `/harvest/done/:batchId`.
- **API**: `POST /batches` via sync worker (body exactly per api-spec §3,
  with `Idempotency-Key`).
- **Offline**: identical happy path — nothing in this flow touches the
  network. Confirmation screen shows batch number huge + QR (QR encodes the
  verify URL, computable offline) + WhatsApp share (`share_plus` text: number
  + `\n` + verify URL; `url_launcher` `whatsapp://` shortcut) + "will sync
  when online" chip. If a 409 later changes the number, the batch card and
  detail always render the current `Batches.batchNo`.
- **Validation**: weight > 0, tree count ≥ 1, date ≤ today; errors inline in
  Sinhala, announced via `Semantics(liveRegion)`.

### 4.5 Batches list + detail with chain timeline (`features/batches/`)

- **Screens**: `batches_list_screen.dart` (cards: number, kg, type icon,
  date, status chip, sync-state icon: pending/error; filter by active role);
  `batch_detail_screen.dart` (header with number + status, upward
  `ChainTimeline` widget — vertical timeline of `BatchEventsCache` rows: icon
  per event_type, actor role, summary, date, anchor check mark; farm origin
  card at top with district-level location).
- **State**: `batchesListProvider(activeRole, query)` stream over drift;
  `batchDetailProvider(id)` = AsyncNotifier: emit cached row + cached chain
  immediately, then refresh `GET /batches/{id}` when online.
- **API**: `GET /batches` (pull), `GET /batches/{id}` (chain), `GET
  /batches/{id}/chain` if detail needs a refresh without full body.
- **Offline**: list and last-seen chain render from cache; detail shows "last
  updated" stamp; transfer/QR actions remain available (transfer queues
  offline).

### 4.6 QR display / share / scan (`features/qr/`)

- **Screens**: `qr_display_screen.dart` (big QR via `qr_flutter`, batch
  number underneath, share buttons); `qr_scan_screen.dart` (mobile_scanner
  viewfinder + torch hint).
- **State**: scan result handled by `ScanResolver`.
- **Resolution logic** (`scan_resolver.dart`): payload → if it matches
  `https://verify.<domain>/{no}` extract `no` (percent-decode — needed for
  M2 `/P1` suffixes) else treat raw payload as a batch number if
  `isValidBatchNo`. Then: (1) local lookup `Batches` by `batchNo` → open
  detail (works offline); (2) else online `GET /batches/by-no/{no}` (auth;
  200 → detail with chain pull); (3) on 403/404 fall back to public `GET
  /verify/{no}` → read-only public chain view (verdict banner + chain, no
  actions).
- **API**: as above; plus `POST /qr/scan` optional server-side decode
  (client-side decode suffices in M1 — skip to save a round trip).
- **Offline**: display + local resolution fully offline; unresolvable scans
  show plain-language "not found on this phone — connect to check".

### 4.7 Transfer flow (`features/transfer/`)

- **Screens**: `transfer_flow.dart` — Step 1 recipient: search field
  (mobile/name, debounced 400 ms) + "Scan QR" alternative; results filtered
  client-side by `transfer_matrix[activeRole]` and re-filtered server-side by
  role from `GET /transfers/recipients?q=`; Step 2 confirm: recipient card,
  batch summary, SALE/HANDOFF toggle (big segmented buttons), price field
  (numeric, shown for SALE; record-only), notes optional → confirm.
- **State**: `recipientSearchProvider` (AsyncNotifier, cancels stale dio
  calls), transfer draft in local state.
- **API**: `GET /transfers/recipients?q=`, `POST /batches/{id}/transfer` via
  outbox (body per spec §4).
- **Offline**: recipient search requires network — search box shows cached
  recent recipients (last-used table could be added later; M1: hint text
  only). The transfer itself queues offline: local `Batches.status →
  IN_TRANSIT` optimistically, outbox entry depends on the batch entry being
  SYNCED (a batch that hasn't synced yet can't be transferred — server needs
  it first; dependency ordering handles this automatically). Success
  confirmation screen with big check.
- **Matrix constant** (`transfer_matrix.dart`): `{FARMER: {COLLECTOR,
  PROCESSOR_L1}, COLLECTOR: {COLLECTOR, PROCESSOR_L1, PROCESSOR_L2,
  EXPORTER}, PROCESSOR_L1: {COLLECTOR, PROCESSOR_L2, EXPORTER}, PROCESSOR_L2:
  {COLLECTOR, EXPORTER}, EXPORTER: {}}` — per PLAN §3.4, server re-checks.

### 4.8 Inbox (`features/inbox/`)

- **Screens**: `inbox_screen.dart` (cards: batch no, from-name + role, kg,
  SALE/HANDOFF chip, Accept button, View button → batch detail public-chain
  view until accepted).
- **State**: `inboxProvider` stream over `InboxItems`; unread count feeds
  Home banner + tab badge.
- **API**: `GET /inbox` (pull on resume + every drain cycle), `POST
  /inbox/{transferId}/accept` via outbox with idempotency key; on success
  local batch upserted with status `RECEIVED`, holder = me.
- **Offline**: pending items render from cache; Accept queues offline and the
  card flips to "accepted — will sync". SALE default = accept immediately per
  spec.

---

## 5. Navigation

**Choice: `go_router`** (over raw Navigator 2). Reasoning: Navigator 2 gives
no value here that go_router doesn't wrap — go_router provides declarative
redirect guards (auth + first-farm gating), `ShellRoute` for the persistent
bottom-nav scaffold, typed path params for `/batch/:id` and
`/harvest/done/:id`, and deep-link hooks we can later wire to QR scans — with
a fraction of the boilerplate, which matters for a one-dev team.

```dart
GoRouter(
  redirect: (context, state) {
    if (!auth.isAuthenticated && !state.matchedLocation.startsWith('/auth')) return '/auth';
    if (auth.isAuthenticated && state.matchedLocation.startsWith('/auth')) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/auth', builder: ...),           // register/login
    GoRoute(path: '/otp',  builder: ...),
    ShellRoute(builder: (_, __, child) => AppShell(child: child), routes: [
      GoRoute(path: '/home',     builder: ...),     // role-variant home
      GoRoute(path: '/batches',  builder: ...),
      GoRoute(path: '/batch/:id', builder: ...),
      GoRoute(path: '/qr',       builder: ...),     // scan tab
      GoRoute(path: '/qr/show/:batchId', builder: ...),
      GoRoute(path: '/inbox',    builder: ...),
    ]),
    GoRoute(path: '/harvest', builder: ...),        // wizard (full-screen, outside shell)
    GoRoute(path: '/harvest/done/:batchId', builder: ...), // big confirmation
    GoRoute(path: '/farm/new', builder: ...),       // farm wizard
    GoRoute(path: '/transfer/:batchId', builder: ...),
  ],
)
```

**Multi-role scoping mechanics**: single login, single router.
`activeRoleProvider` (persisted in `MetaKv`) is read by: the shell header
chips (rendered only if `user.roles.length > 1`; tap switches scope in place
— no navigation, just state), the home body (`switch(activeRole)` →
FarmerHome or HolderHome), FAB visibility (FARMER only), batches list query
(`role=` param), transfer recipient filtering (matrix row), and inbox
relevance (receiving roles). Switching role never clears local data; batches
of all roles stay in drift, filtered at query time. Deep links into
`/batch/:id` work regardless of active role (visibility is server-enforced
anyway).

---

## 6. Localization + accessibility + performance

**Sinhala font handling.** Bundle `NotoSansSinhala-Regular.ttf` +
`NotoSansSinhala-Bold.ttf` in `assets/fonts/` (declared in pubspec; two
weights only — ≈0.5 MB total). Set as the default `fontFamily` in
`ThemeData.typography` so Sinhala renders without font fallback flashes on
Android Go devices that may lack the font. Verify complex shaping (combining
signs, rakaransaya) renders correctly on a real low-end device in WP1 —
Flutter's Skia path handles it, but this is a go/no-go check.

**String workflow.** `l10n.yaml` with `arb-dir: lib/l10n`,
`template-arb-file: app_en.arb`, `output-localization-file:
app_localizations.dart`, synthetic package off (`nullable-getter: false`).
Rules: keys added in `app_en.arb` first, Sinhala translations required in the
same PR before merge (no hardcoded UI strings anywhere — enforced by review,
`flutter analyze` custom lint later); interpolations typed (`{count}`,
`{batchNo}`); dates via `DateFormat.yMMMd('si')`, weights via
`NumberFormat('#,##0.#', 'si')`; language toggle (si/en) in onboarding +
profile persists to `MetaKv` and `PUT /auth/me`; Tamil ARB stubbed empty for
M2. Batch numbers are never localized or wrapped — always displayed verbatim,
monospace-ish, uppercase.

**Accessibility.** Minimum 16sp body text (`TextTheme.bodyMedium: 16`), all
labels ≥ 14sp; every touch target ≥ 48×48dp (`MinimumTouchTargetSize` +
explicit `SizedBox` heights of 56dp for primary buttons); icon + text on
every button, no icon-only controls; numeric keypads everywhere numbers are
entered (`TextInputType.number`, decimal only for weight/size/price);
`Semantics(label:)` on every interactive element, `liveRegion: true` on the
offline banner and error text so TalkBack announces them; batch number on
confirmation screen given a `Semantics` label spelling it in words/groups
("G M, one seven two, …") for screen-reader legibility; contrast ratio ≥
4.5:1 (dark-green on white primary palette, no light-grey-on-white); entire
harvest + transfer flow walked with TalkBack enabled on a real device as an
acceptance step in WP10.

**Performance budget.** APK ≤ 25 MB (expect ~15–20 MB: release mode, R8
default, `--tree-shake-icons`, two font weights only, no bundled images
beyond a few small harvest-type icons, no photos in M1); cold start ≤ 3.5 s
to interactive Home on a 2 GB/Android Go device (targets: defer drift open to
first repo access, no network blocking startup, `flutter build apk
--split-debug-info=build/symbols`). Memory: map created only inside the farm
wizard and disposed on exit; tile cache capped at ~50 MB (`flutter_map`
file-based cache in `path_provider` app dir); image cache left at defaults
(few images). Low-end specifics: no blur/shadow animations, transitions
limited to `MaterialPage` defaults, lists are plain `ListView.builder`
(lazy), QR render size capped at 280px and rasterized once (`qr_flutter` is
lightweight), avoid `BackdropFilter` entirely. OSM tiles cached per district
bounding box so the farm map opens offline after first use.

---

## 7. M1 work packages (sequential, one developer)

### WP1 — Scaffold, theme, i18n, CI skeleton
Flutter project (`com.cinnamontrace.app`), folder structure per §1, pubspec
per §2, strict lints, `--dart-define` for `API_BASE_URL`/`VERIFY_BASE_URL`,
theme with §6 sizes, Noto Sans Sinhala wired, l10n pipeline with first 20
strings, empty go_router with `/auth` and shell stubs, GitHub Actions stub
(analyze + test).
**Accept:** `flutter run` shows shell with Sinhala labels on an Android Go
emulator; shaping renders correctly; CI green; APK ≤ 25 MB from day one
(checked in CI).

### WP2 — drift schema + repositories
All tables from §3.1, codegen, DAOs (`FarmsDao`, `BatchesDao`, `OutboxDao`,
`SeqDao`, `MetaDao`), transactional harvest-insert + counter bump, unit tests
for DAO transactions (incl. unique `batch_no` violation and counter
concurrency).
**Accept:** all tables created on device; transaction test proves
batch+counter+outbox insert atomically; no codegen drift in CI
(`build_runner` check).

### WP3 — API client + auth repository
dio with `AuthInterceptor` (JWT from secure storage, 401 → auth event),
`ApiException` mapping (`error.code` surfaced), endpoint wrappers for
api-spec §1–§4, `AuthRepository` (login/logout/token TTL from `expires_in`).
**Accept:** unit tests with mocked dio cover: JWT attach, 401 event emission,
error-code mapping (409/429/400 details), timeout handling on slow rural
networks (30 s receive timeout, no silent hang).

### WP4 — Auth/OTP + role selection UI
Register screen (validation, role cards), OTP screen (6-digit boxes, paste
support, resend countdown, attempt errors, 429 rate-limit messaging), login
path, router redirects live.
**Accept:** register → OTP → shell works against staging API; re-login after
token expiry preserves all local data; offline shows clear connectivity
message; widget tests for OTP input and role multi-select.

### WP5 — Sync engine
`OutboxRepository`, `SyncWorker` (§3.2: drain loop, dependency-aware pick
query, backoff, 409 regeneration, FAILED_PERMANENT paths),
`ConnectivityMonitor`, `PullService`, offline banner + manual "Sync now".
**Accept:** unit tests with in-memory drift + mocked dio: ordering (farm
before batch), retry backoff schedule, 409 → SEQ increment → new number →
retry with rotated key, regen cap, FAILED_PERMANENT on 400, drain
single-flight; manual test: airplane-mode enqueue → reconnect → queue drains.

### WP6 — Farm wizard + map
District → area-code lookup JSON, map pin screen (flutter_map + OSM + tile
cache + manual lat/lng fallback), size/privacy steps, farm list on Home,
outbox enqueue, `farmer_code` activation on sync, "waiting for first sync"
gating.
**Accept:** farm created fully offline appears locally; after coming online
it syncs and shows farmer code; harvest blocked with plain-language message
until code arrives; map pin + manual entry both produce valid lat/lng; widget
test for district→area mapping.

### WP7 — Harvest wizard + batch numbers + confirmation
Generator + SEQ allocation (§3.3), 5-step wizard, live number preview on
review step, confirmation screen (huge number, QR, WhatsApp share via
share_plus/url_launcher, sell-now shortcut), pending-sync chip.
**Accept:** complete harvest in airplane mode end-to-end in < 60 s; number
matches generator spec; §3.3 test cases all green; QR payload = verify URL;
share sheet works on-device.

### WP8 — Batches list/detail + chain + QR scan
List + detail with `ChainTimeline`, cache-first detail provider, QR display
screen, scan screen + `ScanResolver` (local → authenticated → public
fallback).
**Accept:** detail renders cached chain offline immediately and refreshes
online; scanning own batch QR offline opens detail; scanning unknown number
online resolves via by-no then public verify; widget tests for timeline
rendering and resolver branches.

### WP9 — Transfer + inbox
Recipient search (debounce, dio cancellation), matrix filtering,
SALE/HANDOFF confirm, optimistic IN_TRANSIT, inbox list + accept via outbox,
Home banner with counts.
**Accept:** offline transfer queues and flips status optimistically; matrix
shows farmer only CL/P1 (unit-tested against constant); accept works offline
→ syncs; duplicate accept idempotent (same key returns original).

### WP10 — E2E hardening + performance + release
Full farmer→collector scenario on two devices/emulators (register both,
farmer harvests offline, syncs, transfers; collector sees inbox, accepts,
views upward chain, farmer sees no downstream), 409 collision drill (seed
conflicting number server-side), TalkBack walkthrough of harvest + transfer,
cold-start profiling on 2 GB device, APK size check, crash-free smoke on
Android Go.
**Accept:** E2E script in `integration_test/farmer_to_collector_test.dart`
passes against staging; cold start ≤ 3.5 s measured; APK ≤ 25 MB; all WP
acceptance states re-verified; signed release APK artifact produced by CI.

---

## 8. Testing strategy

**Unit tests (no Flutter binding):**
- `batch_number_generator_test.dart` — all 10 cases in §3.3.
- `transfer_matrix_test.dart` — every cell of the PLAN §3.4 matrix, both
  directions.
- Sync engine: `sync_worker_test.dart`, `outbox_repository_test.dart` against
  `NativeDatabase.memory()` with mocktail-mocked dio — dependency ordering,
  backoff schedule (inject fake clock), 409 regeneration (assert new SEQ, new
  number, rotated idempotency key, counter updated), regen cap →
  FAILED_PERMANENT, 401 pause, idempotent retry returns original result path.
- DAOs: harvest transaction atomicity, unique batch_no, `SeqCounters` upsert.

**Widget tests (`flutter_test`):**
- Harvest wizard: step gating (can't advance with weight 0), date capped at
  today, live number preview updates per farm/type, confirm writes via mocked
  repository.
- OTP screen: 6-digit entry, resend countdown, error announcement semantics.
- Role chips: switching active role swaps home body and FAB visibility
  (multi-role user) and hides chips for single-role user.
- Batches list: sync-state icons (pending/error/synced), status chips;
  transfer recipient list respects matrix filter.
- Offline banner shows and "Sync now" triggers worker (mocked).

**Integration tests (`integration_test/`, on device/emulator):**
- `farmer_to_collector_test.dart`: the WP10 scenario, run against a staging
  backend (or a fixture NestJS instance).
- Offline drill: enable airplane mode (adb via test harness or manual
  pre-step), create harvest, assert local-only state, disable, assert drain +
  SYNCED.
- Collision drill: pre-seed `GM-xxx-01-…` server-side, create same number
  locally, assert client regenerates to `-02-` and syncs.

**CI (GitHub Actions, `.github/workflows/ci.yml`):**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4        # JDK 17, Temurin
      - uses: subosito/flutter-action@v2    # channel: stable, cache: true
      - run: flutter pub get
      - run: dart format --set-exit-if-changed lib test
      - run: flutter analyze
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: git diff --exit-code           # fail if codegen out of sync
      - run: flutter test --coverage
      - run: flutter build apk --release --split-debug-info=build/symbols
      - uses: actions/upload-artifact@v4
        with: { name: app-release-apk, path: build/app/outputs/flutter-apk/app-release.apk }
```
(Integration tests run on demand against staging via `flutter test
integration_test -d <device>` — not in the PR loop since they need a
backend.)

---

**Contract assumptions flagged to the backend team before WP5/WP6:**
1. `POST /farms` and `POST /batches` must accept and echo the client-supplied
   UUIDv7 `id` so offline entities can be referenced before they sync.
   *(Accepted — api-spec.md amended 2026-08-18.)*
2. A `changed_since` cursor on `GET /batches` would replace the full-list
   pull once volumes grow. *(Backlog, M2.)*

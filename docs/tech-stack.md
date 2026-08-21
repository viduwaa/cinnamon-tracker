# Tech Stack Decision

**Status:** DECIDED (2026-08-18) · Supersedes the open options in `PLAN.md` §7
**Blockchain platform is deliberately NOT part of this decision** — see
`blockchain-discussion.md` (separate discussion track). Nothing in the MVP is
blocked by it.

## Decision at a glance

| Layer | Choice | Notes |
|-------|--------|-------|
| Mobile app | **Flutter 3 (stable), Dart 3** | Android-first (minSdk 23); iOS later |
| App state | Riverpod 2 | Compile-safe, testable, no boilerplate |
| App local DB | drift (SQLite) | Offline source of truth on device |
| App networking | dio | Retries, interceptors, idempotency headers |
| Maps | flutter_map + OpenStreetMap tiles | Free, cacheable for offline; manual lat/lng fallback |
| QR | qr_flutter (generate) + mobile_scanner (scan) | |
| Localization | flutter_localizations + intl | Sinhala + English for MVP; Tamil in M2. Bundle Noto Sans Sinhala |
| Backend | **NestJS 11 (TypeScript 5), modular monolith** | One module per bounded context |
| ORM / data access | Prisma **+ raw SQL migrations** | RLS, triggers, recursive CTEs stay in raw SQL |
| Database | **PostgreSQL 16** (+ pgcrypto) | PostGIS deferred until plot polygons (M3) |
| Auth | JWT access tokens + SMS OTP | SMS gateway behind an `SmsProvider` interface; mock provider in dev |
| Public verify portal | Server-rendered from NestJS (Handlebars) | No separate frontend for MVP |
| Blockchain anchoring | Pluggable `AnchorService` interface | Network choice pending separate discussion |
| Hosting | VPS + Docker Compose + Caddy reverse proxy | Cheap, low-latency from SL; managed Postgres optional |
| CI/CD | GitHub Actions | Lint + tests on PR, APK artifacts; Play internal track in M2 |
| Error monitoring | Sentry (app + API, free tier) | |
| Logging | pino structured JSON | |

## Why Flutter (over React Native, native Kotlin)

- The offline-first story is the strongest of the cross-platform options:
  drift/SQLite, background sync, and no JS-bridge overhead on low-RAM devices.
- Sinhala text rendering and font bundling are first-class.
- One codebase now covers Android (the only MVP target); iOS and any later
  kiosk/verify UI come free.
- Pure-Dart shared logic: the batch-number generator and validation rules are
  unit-testable without a device.
- React Native was the runner-up; its offline sync options (WatermelonDB) and
  bridge behavior on 2GB Android Go devices are the weaker risk. Native
  Kotlin doubles effort for zero MVP benefit.

## Why NestJS + Prisma (over FastAPI, Laravel, Firebase)

- End-to-end TypeScript: validation logic, DTO types, and tooling shared with
  the app team's language; one hiring profile.
- NestJS modules map 1:1 to our bounded contexts (identity, farms, batches,
  transfers, verify, anchor) — a disciplined modular monolith, splittable
  later if ever needed.
- Prisma gives fast CRUD DX; everything exotic (row-level security, triggers,
  recursive chain queries) lives in raw SQL migrations, so the database stays
  the single source of integrity.
- Firebase rejected: lineage/RLS-style queries fight the document model,
  vendor lock-in, unpredictable cost at export volumes.
- Laravel is the local-talent fallback if TS hiring fails — acceptable, decide
  before scaffolding only. FastAPI is fine but splits the language stack.

## Why PostgreSQL

- Relational integrity for the append-only event ledger, recursive CTEs for
  chain walks, and row-level security for the upward-only visibility rule — all
  native, all in `schema.sql`.
- PostGIS stays off until M3 plot polygons; `NUMERIC(9,6)` lat/lng covers MVP
  and district-level EUDR reporting.

## Environment facts (dev machine, 2026-08-18)

- Node v24.14.1 ✓ · npm 11.11.0 ✓ · git 2.53 ✓
- **Flutter SDK: not installed** → Sprint 0 action #1
- **Docker: not installed** → local Postgres via native Windows installer or
  Docker Desktop; choose in Sprint 0 (native installer is the lighter path)

## What would make us revisit

- Team skills strongly PHP/Laravel or Python → revisit backend **before**
  scaffolding (cheap now, painful after M1).
- Pilots demand Google Maps specifically → revisit maps (offline caching
  changes; API key + cost implications).
- An exporter or regulator requires a specific chain for verification →
  handled in the blockchain discussion, not here; the `AnchorService`
  interface keeps the app insulated either way.

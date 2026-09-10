# admin-web — Cinnamon Trace Oversight Console

Government-facing read dashboard for the Department of Cinnamon Development.
Separate login (email + password, `admin_users` table), separate domain in
production; reads the same Neon database as the mobile app's API. The ledger
itself is **read-only** here — the only write paths are user
suspend/reactivate and role adjustment, both audit-logged.

## Run

```bash
# terminal 1 — API (repo /backend)
npm run start          # :3100

# terminal 2 — console dev server
npm run dev            # :5173, proxies /v1 → :3100
```

First admin account: from `backend/`,
`node -r dotenv/config scripts/admin-bootstrap.mjs <email> "<Name>" [password]`
(prints a generated password when omitted; re-running rotates it).

## Design system

`DESIGN.md` (Google's DESIGN.md spec) is the single source of truth — the
"Cinnamon Harvest" palette ported from the mobile app
(`app/lib/app/theme.dart`). The `@theme` block in `src/index.css` is generated:

```bash
npx -y -p @google/design.md designmd lint DESIGN.md
npx -y -p @google/design.md designmd export --format css-tailwind DESIGN.md > src/index.css
# (then re-prepend `@import "tailwindcss";` — the export replaces the file)
```

Verdict colors are compliance signals — never reuse them for other states:
AUTHENTIC = leaf on leaf-soft, PENDING = `#8A5A10` on quill-soft, TAMPERED =
clay-dark on clay-soft (AA-contrast-checked via the linter).

## Pages

| Route | What |
|---|---|
| `/` | KPIs, verdict breakdown, 14-day trend, batches-per-role, district volumes |
| `/users` | search / role / status filters, suspend & reactivate (confirm + audit) |
| `/batches` | search, verdict/status/holder-role/district filters, CSV export |
| `/batches/:batchNo` | verdict, origin farm, anchors, full hash-chain timeline |
| `/anchors` | nightly OpenTimestamps runs, failures, events awaiting anchor |
| `/audit` | who did what — admin + app audit stream, filterable |

## Proof

- `backend` API smoke: `bash scripts/run-admin-smoke.sh` (26 checks, needs
  `ADMIN_SMOKE_PASSWORD`)
- console E2E (real browser, uses system Edge): `node scripts/admin-e2e.mjs`
  from `admin-web/` while both dev servers run

## Production

Build with `npm run build` → serve `dist/` on its own domain (e.g.
`admin.cinnamontrace.lk`) behind nginx, reverse-proxying `/v1` to the API.
Cookies/localStorage are origin-scoped, so admin tokens on the admin domain
are never readable by the public verify page.

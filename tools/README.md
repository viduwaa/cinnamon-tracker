# Local dev tooling (portable, no admin rights)

This folder holds self-contained dev tools downloaded as zips so the project
runs without system-wide installs.

| Item | Source | Purpose |
|------|--------|---------|
| `postgresql-16.zip` → `pgsql/` + `pgdata/` | EnterpriseDB portable build | Local PostgreSQL 16 for the backend |
| `flutter-sdk.zip` → `flutter/` | flutter.dev stable channel | Flutter SDK for the mobile app |

## Postgres

```bash
./setup-postgres.sh     # extract, initdb, start on port 5433, create db+role
./stop-postgres.sh      # stop the instance
```

Then point the backend at it:

```
DATABASE_URL=postgres://cinnamon:cinnamon@localhost:5433/cinnamon
```

Run migrations from `backend/`:

```bash
DATABASE_URL=postgres://cinnamon:cinnamon@localhost:5433/cinnamon node dist/migrate.js
```

## Flutter

Extract `flutter-sdk.zip` here, then add `tools/flutter/bin` to PATH for the
session:

```bash
export PATH="$(pwd)/flutter/bin:$PATH"
flutter doctor
```

> These zips and extracted dirs are git-ignored (see root `.gitignore`).

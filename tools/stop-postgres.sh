#!/usr/bin/env bash
# Stop the portable Postgres instance.
set -euo pipefail
cd "$(dirname "$0")"
PGDIR="$(pwd)/pgsql"
DATADIR="$(pwd)/pgdata"
"$PGDIR/bin/pg_ctl.exe" -D "$DATADIR" stop
echo "Postgres stopped."

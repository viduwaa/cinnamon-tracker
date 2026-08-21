#!/usr/bin/env bash
# One-time local Postgres setup from the portable zip (no admin rights).
# Run from the cinnamon-tracker/tools directory.
set -euo pipefail
cd "$(dirname "$0")"

PGDIR="$(pwd)/pgsql"
DATADIR="$(pwd)/pgdata"
PORT=5433   # avoid clashing with any system Postgres on 5432

if [ ! -d "$PGDIR" ]; then
  echo "Extracting postgresql-16.zip..."
  unzip -q postgresql-16.zip
fi

if [ ! -d "$DATADIR" ]; then
  echo "Initializing database cluster at $DATADIR..."
  "$PGDIR/bin/initdb.exe" -D "$DATADIR" -U postgres -A trust --encoding=UTF8
fi

echo "Starting Postgres on port $PORT..."
"$PGDIR/bin/pg_ctl.exe" -D "$DATADIR" -o "-p $PORT" -l "$(pwd)/pg.log" start

echo "Creating role + database..."
"$PGDIR/bin/psql.exe" -p $PORT -U postgres -c "DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='cinnamon') THEN
    CREATE ROLE cinnamon LOGIN PASSWORD 'cinnamon';
  END IF;
END \$\$;"
"$PGDIR/bin/psql.exe" -p $PORT -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='cinnamon'" | grep -q 1 \
  || "$PGDIR/bin/psql.exe" -p $PORT -U postgres -c "CREATE DATABASE cinnamon OWNER cinnamon"

echo ""
echo "Postgres ready on port $PORT."
echo "DATABASE_URL=postgres://cinnamon:cinnamon@localhost:$PORT/cinnamon"

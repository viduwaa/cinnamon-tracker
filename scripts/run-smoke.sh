#!/usr/bin/env bash
# Boots the API from dist, runs the Phase-2 smoke, shuts the API down.
set -u
cd "$(dirname "$0")/../backend" || exit 1
node -r dotenv/config dist/main.js > "$LOCALAPPDATA/Temp/ct-api.log" 2>&1 &
SV=$!
sleep 7
cd .. || exit 1
node scripts/phase2-smoke.mjs
SMOKE=$?
kill "$SV" 2>/dev/null
wait "$SV" 2>/dev/null
echo "SMOKE_EXIT=$SMOKE"
exit "$SMOKE"

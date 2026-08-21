#!/usr/bin/env bash
# End-to-end smoke test against a running backend + live Postgres.
# Exercises: register → OTP → farm → harvest batch → transfer → accept → verify.
set -euo pipefail

API="${API:-http://localhost:3100/v1}"
LOG="${LOG:-/tmp/nest-boot.log}"

say() { echo ""; echo "=== $1 ==="; }
jqget() { python -c "import sys,json; d=json.load(sys.stdin); print(d$1)"; }

say "1. Register farmer"
FARMER=$(curl -s -X POST "$API/auth/register" -H "Content-Type: application/json" \
  -d '{"name":"Sunil Perera","mobile":"+94771111111","roles":["FARMER"],"preferred_lang":"si"}')
echo "$FARMER" | jqget "['name']"

say "2. Request OTP (mock SMS logs the code)"
curl -s -X POST "$API/auth/otp/request" -H "Content-Type: application/json" \
  -d '{"mobile":"+94771111111"}' > /dev/null
sleep 1
CODE=$(grep -o 'verification code is [0-9]*' "$LOG" | tail -1 | grep -o '[0-9]*')
echo "OTP code from mock SMS log: $CODE"

say "3. Verify OTP → JWT"
FARMER_TOKEN=$(curl -s -X POST "$API/auth/otp/verify" -H "Content-Type: application/json" \
  -d "{\"mobile\":\"+94771111111\",\"code\":\"$CODE\"}" | jqget "['token']")
echo "token: ${FARMER_TOKEN:0:24}…"

say "4. Create farm (client-supplied UUIDv7)"
# generate a UUIDv7 via node (backend has the helper compiled)
FARM_ID=$(node -e "const{randomFillSync}=require('crypto');const n=Date.now();const b=Buffer.alloc(16);b.writeUIntBE(n,0,6);randomFillSync(b.subarray(6));b[6]=(b[6]&0x0f)|0x70;b[8]=(b[8]&0x3f)|0x80;const h=b.toString('hex');console.log([h.slice(0,8),h.slice(8,12),h.slice(12,16),h.slice(16,20),h.slice(20)].join('-'))")
FARM=$(curl -s -X POST "$API/farms" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FARMER_TOKEN" \
  -d "{\"id\":\"$FARM_ID\",\"name\":\"Home Garden\",\"area_code\":\"GM\",\"size_value\":1.5,\"size_unit\":\"ACRE\",\"lat\":6.0329,\"lng\":80.2168,\"address_text\":\"Walpita, Galle\"}")
echo "$FARM" | jqget "['farmer_code']" | sed 's/^/farmer_code: /'

say "5. Create harvest batch (client-generated batch_no)"
BATCH_ID=$(node -e "const{randomFillSync}=require('crypto');const n=Date.now();const b=Buffer.alloc(16);b.writeUIntBE(n,0,6);randomFillSync(b.subarray(6));b[6]=(b[6]&0x0f)|0x70;b[8]=(b[8]&0x3f)|0x80;const h=b.toString('hex');console.log([h.slice(0,8),h.slice(8,12),h.slice(12,16),h.slice(16,20),h.slice(20)].join('-'))")
BATCH_NO="GM-229-01-2026-FM-A-T"
BATCH=$(curl -s -X POST "$API/batches" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FARMER_TOKEN" \
  -d "{\"id\":\"$BATCH_ID\",\"farm_id\":\"$FARM_ID\",\"batch_no\":\"$BATCH_NO\",\"harvest_type\":\"T\",\"harvest_date\":\"2026-08-17\",\"tree_count\":45,\"weight_kg\":120.5}")
echo "$BATCH" | jqget "['batch_no']" | sed 's/^/batch_no: /'
echo "$BATCH" | jqget "['verification']['chain_head_hash']" | sed 's/^\(................\).*/chain_head_hash: \1…/'

say "6. Duplicate batch_no → expect 409 BATCH_NO_TAKEN"
DUP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/batches" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FARMER_TOKEN" \
  -d "{\"id\":\"$(node -e "const{randomFillSync}=require('crypto');const n=Date.now();const b=Buffer.alloc(16);b.writeUIntBE(n,0,6);randomFillSync(b.subarray(6));b[6]=(b[6]&0x0f)|0x70;b[8]=(b[8]&0x3f)|0x80;const h=b.toString('hex');console.log([h.slice(0,8),h.slice(8,12),h.slice(12,16),h.slice(16,20),h.slice(20)].join('-'))")\",\"farm_id\":\"$FARM_ID\",\"batch_no\":\"$BATCH_NO\",\"harvest_type\":\"T\",\"harvest_date\":\"2026-08-17\",\"tree_count\":10,\"weight_kg\":50}")
echo "HTTP $DUP (expect 409)"

say "7. Register collector + OTP"
curl -s -X POST "$API/auth/register" -H "Content-Type: application/json" \
  -d '{"name":"Kumar Silva","mobile":"+94772222222","roles":["COLLECTOR"]}' > /dev/null
curl -s -X POST "$API/auth/otp/request" -H "Content-Type: application/json" \
  -d '{"mobile":"+94772222222"}' > /dev/null
sleep 1
CODE2=$(grep -o 'verification code is [0-9]*' "$LOG" | tail -1 | grep -o '[0-9]*')
COLLECTOR_TOKEN=$(curl -s -X POST "$API/auth/otp/verify" -H "Content-Type: application/json" \
  -d "{\"mobile\":\"+94772222222\",\"code\":\"$CODE2\"}" | jqget "['token']")
echo "collector token: ${COLLECTOR_TOKEN:0:24}…"

say "8. Farmer looks up recipients (should see collector only)"
curl -s "$API/transfers/recipients?q=Kumar" -H "Authorization: Bearer $FARMER_TOKEN" | jqget ""

say "9. Transfer batch to collector (SALE)"
TRANSFER=$(curl -s -X POST "$API/batches/$BATCH_ID/transfer" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FARMER_TOKEN" \
  -d "{\"to_user_id\":\"$(curl -s "$API/transfers/recipients?q=Kumar" -H "Authorization: Bearer $FARMER_TOKEN" | jqget "[0]['id']")\",\"transfer_kind\":\"SALE\",\"price_lkr\":45000}")
echo "$TRANSFER" | jqget "['status']" | sed 's/^/status: /'

say "10. Collector inbox → accept"
curl -s "$API/inbox" -H "Authorization: Bearer $COLLECTOR_TOKEN" | jqget "[0]['batch_no']" | sed 's/^/inbox batch: /'
ACCEPT=$(curl -s -X POST "$API/inbox/$BATCH_ID/accept" -H "Authorization: Bearer $COLLECTOR_TOKEN")
echo "$ACCEPT" | jqget "['status']" | sed 's/^/after accept: /'

say "11. Collector sees upward chain"
curl -s "$API/batches/$BATCH_ID" -H "Authorization: Bearer $COLLECTOR_TOKEN" | jqget "['chain']"

say "12. Public verify endpoint (no auth)"
curl -s "http://localhost:3100/verify/$BATCH_NO" | jqget "['verdict']" | sed 's/^/verdict: /'

say "DONE — full farmer → collector flow verified"

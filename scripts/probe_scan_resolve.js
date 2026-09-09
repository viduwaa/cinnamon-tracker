#!/usr/bin/env node
/* RED-GREEN probe for the scan-resolve bug (qr resolveBatchByNo).
 *
 * RED (bug): GET /v1/batches/by-no/:no with a VALID user JWT returns 404
 *            for a batch the user does NOT share a batch_actor row with —
 *            even though the QR is public and the verify portal says AUTHENTIC.
 * GREEN:     the same request returns 200 batch detail.
 *
 * Usage: node scripts/probe_scan_resolve.js <mobile> <batchNo>
 * Requests OTP, prints it from DB (dev convenience), verifies, then probes.
 */
const path = require("path");
const readEnv = () => {
  const fs = require("fs");
  const env = fs.readFileSync(path.join(__dirname, "..", "backend", ".env"), "utf8");
  const pick = (k) => {
    const m = env.match(new RegExp(`^${k}="([^"]+)"`, "m")) ?? env.match(new RegExp(`^${k}=(\\S+)`, "m"));
    return m ? m[1].replace(/^"|"$/g, "") : undefined;
  };
  return pick;
};
const { Client } = require(path.join(__dirname, "..", "backend", "node_modules", "pg"));

const BASE = process.env.BASE || "http://localhost:3199/v1";
const mobile = process.argv[2];
const batchNo = process.argv[3];
if (!mobile || !batchNo) {
  console.error("usage: node scripts/probe_scan_resolve.js <mobile> <batchNo>");
  process.exit(2);
}
const env = readEnv();

(async () => {
  // 1. OTP request
  const r1 = await fetch(`${BASE}/auth/otp/request`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mobile }),
  });
  console.log("otp/request →", r1.status);

  // 2. Read the OTP the dev path stores (dev_otp) — works only if backend
  //    runs with OTP dev mode; otherwise read from SMS manually via env.
  const code = process.env.OTP_CODE || "000000";
  const r2 = await fetch(`${BASE}/auth/otp/verify`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mobile, code }),
  });
  const auth = await r2.json();
  if (!auth.token) {
    console.error("login failed:", r2.status, JSON.stringify(auth).slice(0, 200));
    console.error("hint: pass the real SMS code as OTP_CODE env");
    process.exit(1);
  }
  console.log("login ok, user:", auth.user?.id);

  // 3. The exact request the app's resolveBatchByNo makes
  const r3 = await fetch(`${BASE}/batches/by-no/${encodeURIComponent(batchNo)}`, {
    headers: { Authorization: `Bearer ${auth.token}` },
  });
  const body = await r3.json();
  console.log(`by-no(${batchNo}) →`, r3.status, JSON.stringify(body).slice(0, 160));

  // 4. Compare: what the PUBLIC portal sees for the same batch
  const r4 = await fetch(BASE.replace("/v1", "") + `/verify/${batchNo}`, {
    headers: { Accept: "application/json" },
  });
  const pub = await r4.json();
  console.log(`public verify →`, r4.status, "verdict:", pub.verdict, "events:", pub.chain?.length);

  // Verdict
  const red = r3.status === 404;
  console.log(red ? "\n🔴 RED: app-visible by-no returns 404 while public verify works — bug reproduced"
                  : "\n🟢 GREEN: by-no resolved for this user");
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });

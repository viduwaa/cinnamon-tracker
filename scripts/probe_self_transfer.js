#!/usr/bin/env node
/* E2E proof: multi-role user self-handover (farmer → own processor).
 * Login via dev OTP bypass, self-transfer with explicit to_role, repeat
 * must 409 (state machine), accept flips holding role. */
const path = require("path");
const fs = require("fs");
const { Client } = require(path.join(__dirname, "..", "backend", "node_modules", "pg"));
const env = fs.readFileSync(path.join(__dirname, "..", "backend", ".env"), "utf8");
const pick = (k) => {
  const m = env.match(new RegExp(`^${k}="?([^"\\n]+)"?`, "m"));
  return m ? m[1] : undefined;
};
const BASE = "http://localhost:3199/v1";

(async () => {
  // resolve Vidula's real mobile from DB (registered as typed at signup)
  const c = new Client({ connectionString: pick("DATABASE_URL") });
  await c.connect();
  const u = await c.query("SELECT id, mobile FROM users WHERE name ILIKE '%vidula%'");
  await c.end();
  const mobile = u.rows[0].mobile;
  const userId = u.rows[0].id;

  const rq = await fetch(`${BASE}/auth/otp/request`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mobile }),
  });
  const v = await fetch(`${BASE}/auth/otp/verify`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mobile, code: pick("OTP_BYPASS_CODE") }),
  });
  if (!(v.status === 201 || v.status === 200)) {
    return console.log("LOGIN FAILED", v.status, await v.text());
  }
  const a = await v.json();
  const token = a.token;
  console.log("login ok · roles:", (a.user?.roles ?? []).join("+"));

  const H = { Authorization: `Bearer ${token}`, "Content-Type": "application/json" };
  const mineRaw = await (await fetch(`${BASE}/batches?limit=100`, { headers: H })).json();
  const list = Array.isArray(mineRaw) ? mineRaw : mineRaw.data || mineRaw.batches || [];
  console.log("visible batches:", list.length);
  const batch = list.find(
    (b) => b.status === "HARVESTED" && b.current_holder_role === "FARMER",
  );
  if (!batch) {
    return console.log("NO farmer-held HARVESTED batch. Have:",
      list.map((b) => `${b.batch_no}:${b.status}:${b.current_holder_role}`).join(" | "));
  }
  console.log("batch:", batch.batch_no, batch.status, "held as", batch.current_holder_role);

  // 1. self-transfer farmer → own PROCESSOR_L1
  const tr = await fetch(`${BASE}/batches/${batch.id}/transfer`, {
    method: "POST",
    headers: H,
    body: JSON.stringify({ to_user_id: userId, to_role: "PROCESSOR_L1", transfer_kind: "HANDOFF" }),
  });
  const trb = await tr.json();
  console.log("SELF-TRANSFER →", tr.status, JSON.stringify(trb).slice(0, 140));

  // 2. repeat while IN_TRANSIT must 409
  const again = await fetch(`${BASE}/batches/${batch.id}/transfer`, {
    method: "POST", headers: H,
    body: JSON.stringify({ to_user_id: userId, to_role: "PROCESSOR_L1", transfer_kind: "HANDOFF" }),
  });
  console.log("REPEAT →", again.status, "(expect 409 NOT_PENDING)");

  // 3. accept (same user, now acting as PROCESSOR_L1)
  const ac = await fetch(`${BASE}/inbox/${batch.id}/accept`, { method: "POST", headers: H });
  const acb = await ac.json();
  console.log("ACCEPT →", ac.status, JSON.stringify(acb).slice(0, 160));

  // 4. chain tail shows the role-switch custody events
  const ch = await (await fetch(`${BASE}/batches/${batch.id}/chain`, { headers: H })).json();
  const tail = (ch.events ?? []).slice(-2).map((e) => `${e.event_type}:${e.actor_role}`).join(" | ");
  console.log("CHAIN TAIL:", tail);
  console.log("HOLDER NOW:", ch.current_holder_role ?? "(in batch fields)");
})().catch((e) => { console.error(e); process.exit(1); });

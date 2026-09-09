#!/usr/bin/env node
/* Diagnose why GET /v1/batches returns 0 for Vidula while the DB says
 * she holds NU-252-01-2026-FM-A-Q. Prints the actual HTTP response body. */
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
  const c = new Client({ connectionString: pick("DATABASE_URL") });
  await c.connect();
  const u = await c.query("SELECT mobile FROM users WHERE name ILIKE '%vidula%'");
  await c.end();
  const mobile = u.rows[0].mobile;
  await fetch(`${BASE}/auth/otp/request`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mobile }),
  });
  const v = await fetch(`${BASE}/auth/otp/verify`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mobile, code: pick("OTP_BYPASS_CODE") }),
  });
  const a = await v.json();
  const H = { Authorization: `Bearer ${a.token}` };
  console.log("login:", v.status, "user.roles:", (a.user?.roles ?? []).join("+"));
  const r = await fetch(`${BASE}/batches?limit=100`, { headers: H });
  const body = await r.text();
  console.log("GET /batches →", r.status);
  console.log("body:", body.slice(0, 400));
  // ALSO: raw JWT sub vs DB id
  console.log("jwt sub:", a.user?.id);
})().catch((e) => { console.error(e); process.exit(1); });

#!/usr/bin/env node
/* Full mobile of Vidula (E2E self-transfer login). Local dev DB only. */
const path = require("path");
const { Client } = require(path.join(__dirname, "..", "backend", "node_modules", "pg"));
const fs = require("fs");
const env = fs.readFileSync(path.join(__dirname, "..", "backend", ".env"), "utf8");
const m = env.match(/^DATABASE_URL="?([^"\n]+)"?/m);
(async () => {
  const c = new Client({ connectionString: m[1] });
  await c.connect();
  const r = await c.query("SELECT regexp_replace(mobile, '[^0-9+]', '', 'g') AS full_mobile FROM users WHERE name ILIKE '%vidula%'");
  console.log(r.rows.map((x) => x.full_mobile).join(","));
  await c.end();
})().catch((e) => { console.error("ERR", e.message); process.exit(1); });

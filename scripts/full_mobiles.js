#!/usr/bin/env node
/* Full mobiles of users (local dev DB only; needed for dev-login E2E). */
const path = require("path");
const { Client } = require(path.join(__dirname, "..", "backend", "node_modules", "pg"));
const fs = require("fs");
const env = fs.readFileSync(path.join(__dirname, "..", "backend", ".env"), "utf8");
const m = env.match(/^DATABASE_URL="?([^"\n]+)"?/m);
(async () => {
  const c = new Client({ connectionString: m[1] });
  await c.connect();
  const r = await c.query("SELECT name, mobile FROM users ORDER BY name");
  for (const row of r.rows) process.stdout.write(`${row.name}|${row.mobile}\n`);
  await c.end();
})().catch((e) => { console.error("ERR", e.message); process.exit(1); });

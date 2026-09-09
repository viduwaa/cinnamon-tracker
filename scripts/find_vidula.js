#!/usr/bin/env node
/* Find Vidula's exact mobile (needed for the E2E self-transfer login). */
const path = require("path");
const { Client } = require(path.join(__dirname, "..", "backend", "node_modules", "pg"));
const fs = require("fs");
const env = fs.readFileSync(path.join(__dirname, "..", "backend", ".env"), "utf8");
const m = env.match(/^DATABASE_URL="?([^"\n]+)"?/m);
(async () => {
  const c = new Client({ connectionString: m[1] });
  await c.connect();
  const r = await c.query("SELECT mobile, name FROM users WHERE name ILIKE '%vidula%' OR mobile LIKE '%8957'");
  console.log(JSON.stringify(r.rows));
  await c.end();
})().catch((e) => { console.error("ERR", e.message); process.exit(1); });

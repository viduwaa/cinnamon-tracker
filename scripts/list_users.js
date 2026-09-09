#!/usr/bin/env node
/* Full unmasked mobiles of users (local dev DB only, not printed to logs). */
const path = require("path");
const { Client } = require(path.join(__dirname, "..", "backend", "node_modules", "pg"));
const fs = require("fs");
const env = fs.readFileSync(path.join(__dirname, "..", "backend", ".env"), "utf8");
const m = env.match(/^DATABASE_URL="?([^"\n]+)"?/m);
(async () => {
  const c = new Client({ connectionString: m[1] });
  await c.connect();
  const r = await c.query(
    "SELECT u.mobile, array_agg(ur.role) AS roles FROM users u LEFT JOIN user_roles ur ON ur.user_id=u.id GROUP BY u.mobile ORDER BY u.mobile"
  );
  for (const row of r.rows) {
    const roles = Array.isArray(row.roles) ? row.roles.join(",") : String(row.roles ?? "");
    console.log(row.mobile, "→", roles);
  }
  await c.end();
})().catch((e) => { console.error("ERR", e.message); process.exit(1); });

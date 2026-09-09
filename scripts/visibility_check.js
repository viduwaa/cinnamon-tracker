#!/usr/bin/env node
/* Check which batches Vidula's user id can see via listMine's SQL
 * (diagnostic for the E2E self-transfer probe getting 0 batches). */
const path = require("path");
const fs = require("fs");
const { Client } = require(path.join(__dirname, "..", "backend", "node_modules", "pg"));
const env = fs.readFileSync(path.join(__dirname, "..", "backend", ".env"), "utf8");
const m = env.match(/^DATABASE_URL="?([^"\n]+)"?/m);
(async () => {
  const c = new Client({ connectionString: m[1] });
  await c.connect();
  const u = await c.query("SELECT id FROM users WHERE name ILIKE '%vidula%'");
  const uid = u.rows[0].id;
  const r = await c.query(
    `
    SELECT b.batch_no, b.status, b.current_holder_role,
           (SELECT count(*)::int FROM batch_actors ba WHERE ba.batch_id=b.id AND ba.user_id=$1) AS actor_rows,
           (b.current_holder_id = $1) AS is_holder
    FROM batches b
    ORDER BY b.created_at DESC`,
    [uid],
  );
  console.log("user:", uid);
  for (const row of r.rows) {
    console.log(`${row.batch_no}  ${row.status}  ${row.current_holder_role}  actor_rows=${row.actor_rows} holder=${row.is_holder}`);
  }
  await c.end();
})().catch((e) => { console.error("ERR", e.message); process.exit(1); });

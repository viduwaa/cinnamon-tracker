#!/usr/bin/env node
/* RED probe: does GET /v1/batches/by-no/:no 404 for a user who is a batch
 * actor under a DIFFERENT role, or with no batch_actor row at all? */
const path = require("path");
const fs = require("fs");
const { Client } = require(path.join(__dirname, "..", "backend", "node_modules", "pg"));

const env = fs.readFileSync(path.join(__dirname, "..", "backend", ".env"), "utf8");
const pick = (k) => {
  const m = env.match(new RegExp(`^${k}="([^"]+)"`, "m")) ?? env.match(new RegExp(`^${k}=(\\S+)`, "m"));
  return m ? m[1].replace(/^"|"$/g, "") : undefined;
};
const url = pick("DATABASE_URL").replace(/^"|"$/g, "");

(async () => {
  const c = new Client({ connectionString: url });
  await c.connect();
  // Custody map: who holds what, under which role, and whether the holder
  // has a batch_actor row (canView's requirement).
  const r = await c.query(`
    SELECT b.batch_no, b.status,
           b.current_holder_role,
           u.name AS holder_name, u.mobile AS holder_mobile,
           (SELECT count(*) FROM batch_actors ba
             WHERE ba.batch_id = b.id AND ba.user_id = u.id) AS actor_rows
    FROM batches b
    LEFT JOIN users u ON u.id = b.current_holder_id
    ORDER BY b.created_at DESC
    LIMIT 8`);
  console.table(r.rows.map((x) => ({
    batch_no: x.batch_no,
    status: x.status,
    holder_role: x.current_holder_role,
    holder: x.holder_name,
    mobile: x.holder_mobile,
    batch_actor_rows: Number(x.actor_rows),
  })));
  await c.end();
})().catch((e) => { console.error("ERR", e.message); process.exit(1); });

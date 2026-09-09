#!/usr/bin/env node
/* Prove the full origin-map pipeline through the LIVE API:
 * 1. flip RUSL FOT to EXACT (dev DB)
 * 2. find its batch
 * 3. GET /verify/:no as a browser → expect the Google Maps iframe
 */
const path = require("path");
const { Client } = require(path.join(__dirname, "..", "backend", "node_modules", "pg"));
const fs = require("fs");
const env = fs.readFileSync(path.join(__dirname, "..", "backend", ".env"), "utf8");
const m = env.match(/^DATABASE_URL="?([^"\n]+)"?/m);

(async () => {
  const c = new Client({ connectionString: m[1] });
  await c.connect();
  const up = await c.query(
    "UPDATE farms SET location_public_level='EXACT' WHERE name='RUSL FOT' RETURNING name, lat, lng, location_public_level",
  );
  console.log("farm now:", JSON.stringify(up.rows[0]));
  const b = await c.query(
    "SELECT batch_no FROM batches b JOIN farms f ON f.id=b.farm_id WHERE f.name='RUSL FOT' ORDER BY b.created_at DESC LIMIT 1",
  );
  await c.end();
  const batchNo = b.rows[0].batch_no;
  console.log("batch:", batchNo);

  const r = await fetch(`http://localhost:3199/verify/${batchNo}`, {
    headers: { Accept: "text/html" },
  });
  const html = await r.text();
  const iframe = html.match(/<iframe[^>]*origin-map[^>]*>/);
  console.log("HTTP", r.status, "iframe:", iframe ? iframe[0].slice(0, 140) : "MISSING");
  const coords = html.match(/Location<\/span>[^<]*</);
  console.log("location row:", coords ? coords[0] : "n/a");
})().catch((e) => { console.error("ERR", e.message); process.exit(1); });

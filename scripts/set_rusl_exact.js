#!/usr/bin/env node
/* Dev-DB only: set RUSL FOT (user's own test farm) to EXACT visibility so the
 * origin map pipeline can be verified end-to-end through the live API. */
const path = require("path");
const { Client } = require(path.join(__dirname, "..", "backend", "node_modules", "pg"));
const fs = require("fs");
const env = fs.readFileSync(path.join(__dirname, "..", "backend", ".env"), "utf8");
const m = env.match(/^DATABASE_URL="?([^"\n]+)"?/m);
(async () => {
  const c = new Client({ connectionString: m[1] });
  await c.connect();
  const r = await c.query(
    "UPDATE farms SET location_public_level = 'EXACT' WHERE name = 'RUSL FOT' RETURNING name, lat, lng, location_public_level",
  );
  console.log("updated:", JSON.stringify(r.rows));
  await c.end();
})().catch((e) => { console.error("ERR", e.message); process.exit(1); });

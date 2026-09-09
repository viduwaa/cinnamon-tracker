// Safety backup: dump every public table to JSON before the wipe.
const path = require('path');
const fs = require('fs');
const { Client } = require(path.join(__dirname, '..', 'backend', 'node_modules', 'pg'));

const env = fs.readFileSync(path.join(__dirname, '..', 'backend', '.env'), 'utf8');
const urlLine = env.split(/\r?\n/).find((l) => l.startsWith('DATABASE_URL_UNPOOLED='));
const connStr = urlLine.slice('DATABASE_URL_UNPOOLED='.length).trim();

(async () => {
  const client = new Client({
    connectionString: connStr,
    ssl: { rejectUnauthorized: true },
    connectionTimeoutMillis: 20000,
  });
  await client.connect();

  const { rows: tables } = await client.query(`
    SELECT relname AS table_name FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r' ORDER BY relname;
  `);

  const dump = { dumped_at: new Date().toISOString(), tables: {} };
  for (const { table_name } of tables) {
    const { rows } = await client.query(`SELECT * FROM "${table_name}"`);
    dump.tables[table_name] = rows;
    console.log(`${table_name.padEnd(20)} ${rows.length} rows`);
  }

  const out = path.join(__dirname, `db-backup-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
  fs.writeFileSync(out, JSON.stringify(dump, null, 2));
  console.log(`\nBackup written: ${out} (${(fs.statSync(out).size / 1024).toFixed(1)} KB)`);
  await client.end();
})().catch((e) => {
  console.error('ERROR:', e.message);
  process.exit(1);
});

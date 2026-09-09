// Read-only row-count inventory of the deployed Neon database.
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
    SELECT c.relname AS table_name,
           COALESCE(s.n_live_tup, 0) AS approx_rows
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
    ORDER BY c.relname;
  `);

  console.log('=== exact row counts ===');
  for (const t of tables) {
    const { rows } = await client.query(`SELECT COUNT(*)::int AS n FROM "${t.table_name}"`);
    console.log(`${t.table_name.padEnd(20)} ${String(rows[0].n).padStart(6)}`);
  }

  // Sample of what the users look like, to confirm test data
  const { rows: users } = await client.query(
    'SELECT name, mobile, created_at FROM users ORDER BY created_at LIMIT 20',
  );
  console.log('\n=== users sample ===');
  for (const u of users) console.log(`${u.name} | ${u.mobile} | ${u.created_at.toISOString()}`);

  const { rows: b } = await client.query(
    'SELECT batch_no, status, created_at FROM batches ORDER BY created_at LIMIT 20',
  );
  console.log('\n=== batches sample ===');
  for (const x of b) console.log(`${x.batch_no} | ${x.status} | ${x.created_at.toISOString()}`);

  const { rows: d } = await client.query('SELECT COUNT(*)::int AS n FROM districts');
  console.log(`\ndistricts rows: ${d[0].n}`);
  await client.end();
})().catch((e) => {
  console.error('ERROR:', e.message);
  process.exit(1);
});

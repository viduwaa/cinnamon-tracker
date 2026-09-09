// Wipe all user-generated data; keep districts (reference) + schema_migrations (bookkeeping).
const path = require('path');
const fs = require('fs');
const { Client } = require(path.join(__dirname, '..', 'backend', 'node_modules', 'pg'));

const env = fs.readFileSync(path.join(__dirname, '..', 'backend', '.env'), 'utf8');
const urlLine = env.split(/\r?\n/).find((l) => l.startsWith('DATABASE_URL_UNPOOLED='));
const connStr = urlLine.slice('DATABASE_URL_UNPOOLED='.length).trim();

const WIPE_TABLES = [
  'batch_events',
  'batch_actors',
  'merge_parents',
  'batches',
  'farms',
  'user_roles',
  'users',
  'idempotency_keys',
  'audit_log',
  'otp_codes',
  'chain_anchors',
];

(async () => {
  const client = new Client({
    connectionString: connStr,
    ssl: { rejectUnauthorized: true },
    connectionTimeoutMillis: 20000,
  });
  await client.connect();

  try {
    await client.query('BEGIN');
    // One statement so cross-table FKs are satisfied; RESTRICT (default)
    // aborts if any referencing table was forgotten. RESTART IDENTITY
    // resets audit_log's identity sequence for a truly fresh start.
    await client.query(
      `TRUNCATE TABLE ${WIPE_TABLES.map((t) => `"${t}"`).join(', ')} RESTART IDENTITY`,
    );
    await client.query('COMMIT');
    console.log('TRUNCATE committed:', WIPE_TABLES.join(', '));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => {});
    throw e;
  }

  // Verify final state
  console.log('\n=== post-wipe counts ===');
  const { rows } = await client.query(`
    SELECT relname AS t FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r' ORDER BY relname;
  `);
  let clean = true;
  for (const { t } of rows) {
    const { rows: r } = await client.query(`SELECT COUNT(*)::int AS n FROM "${t}"`);
    const keep = t === 'districts' || t === 'schema_migrations';
    const ok = keep ? r[0].n > 0 : r[0].n === 0;
    if (!ok) clean = false;
    console.log(`${t.padEnd(20)} ${String(r[0].n).padStart(6)}  ${ok ? 'OK' : 'UNEXPECTED'}`);
  }
  console.log(clean ? '\nDatabase is clean.' : '\nWARNING: unexpected state!');
  await client.end();
  process.exit(clean ? 0 : 1);
})().catch((e) => {
  console.error('ERROR:', e.message);
  process.exit(1);
});

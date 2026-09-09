// Empirically test whether OTP bypass is active on the DEPLOYED api.
// Registers a temp user, then tries /auth/otp/verify with the bypass code
// directly (no OTP request => no SMS is ever sent). Cleans up after via
// direct DB access.
const path = require('path');
const fs = require('fs');
const { Client } = require(path.join(__dirname, '..', 'backend', 'node_modules', 'pg'));

const API = 'https://api-cinnamon.viduwa.dev/v1';
const TEST_MOBILE = '+94710000001'; // temp test account, deleted afterwards

const env = fs.readFileSync(path.join(__dirname, '..', 'backend', '.env'), 'utf8');
const urlLine = env.split(/\r?\n/).find((l) => l.startsWith('DATABASE_URL_UNPOOLED='));
const connStr = urlLine.slice('DATABASE_URL_UNPOOLED='.length).trim();

(async () => {
  // 1. Register temp user (idempotent: 409 MOBILE_TAKEN is fine too)
  const reg = await fetch(`${API}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: 'Bypass Check',
      mobile: TEST_MOBILE,
      roles: ['FARMER'],
      preferred_lang: 'en',
    }),
  });
  console.log('register:', reg.status, await reg.text());

  // 2. Try bypass code directly — bypass path needs no otp_codes row.
  const ver = await fetch(`${API}/auth/otp/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ mobile: TEST_MOBILE, code: '000000' }),
  });
  const body = await ver.json();
  console.log('verify(000000):', ver.status, JSON.stringify(body).slice(0, 300));
  const bypassOn = ver.ok && body.token;

  // 3. Also confirm a WRONG code is rejected (so 000000 isn't just ignored)
  const ver2 = await fetch(`${API}/auth/otp/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ mobile: TEST_MOBILE, code: '999999' }),
  });
  console.log('verify(999999):', ver2.status, (await ver2.text()).slice(0, 200));

  // 4. Cleanup: remove temp user (cascades roles)
  const client = new Client({
    connectionString: connStr,
    ssl: { rejectUnauthorized: true },
    connectionTimeoutMillis: 20000,
  });
  await client.connect();
  const { rowCount } = await client.query('DELETE FROM users WHERE mobile = $1', [TEST_MOBILE]);
  const { rows: left } = await client.query('SELECT COUNT(*)::int AS n FROM users');
  await client.end();
  console.log(`cleanup: deleted ${rowCount} temp user(s); users table now has ${left[0].n} rows`);

  console.log(bypassOn ? '\nRESULT: BYPASS IS ON' : '\nRESULT: BYPASS IS OFF');
  process.exit(0);
})().catch((e) => {
  console.error('ERROR:', e.message);
  process.exit(1);
});

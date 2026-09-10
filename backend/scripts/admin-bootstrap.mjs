// Creates the first admin (or resets one) — run on the server:
//   node dist/admin-bootstrap.js <email> "<Name>" [password]
// Password is generated and printed when omitted. Uses the unpooled URL when
// present (Neon DDL-safe). Idempotent: re-running upserts the same email.
import { randomBytes } from "node:crypto";
import bcrypt from "bcryptjs";
import { readFileSync } from "node:fs";
import { Client } from "pg";

function loadEnv() {
  try {
    const raw = readFileSync(new URL("../.env", import.meta.url), "utf8");
    for (const line of raw.split("\n")) {
      const m = line.match(/^([A-Z_][A-Z0-9_]*)=(.*)$/);
      if (m && !(m[1] in process.env)) process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
    }
  } catch {
    // .env is optional; real env vars win anyway
  }
}

async function main() {
  loadEnv();
  const [email, name, passwordArg] = process.argv.slice(2);
  if (!email || !name) {
    console.error("usage: node dist/admin-bootstrap.js <email> <name> [password]");
    process.exit(1);
  }
  const password = passwordArg ?? randomBytes(12).toString("base64url");
  const hash = await bcrypt.hash(password, 12);
  const url = process.env.DATABASE_URL_UNPOOLED ?? process.env.DATABASE_URL;
  if (!url) {
    console.error("DATABASE_URL is not set");
    process.exit(1);
  }
  const client = new Client({ connectionString: url });
  await client.connect();
  // Idempotent upsert on email; re-running rotates the password.
  const { rows } = await client.query(
    `INSERT INTO admin_users (id, email, name, password_hash)
     VALUES (gen_random_uuid(), $1, $2, $3)
     ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash, is_active = true
     RETURNING id, email`,
    [email.toLowerCase(), name, hash],
  );
  await client.end();
  console.log(`admin ready: ${rows[0].email} (id ${rows[0].id})`);
  if (!passwordArg) console.log(`password: ${password}`);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});

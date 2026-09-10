// Admin console smoke — boots against a running API (see scripts/run-admin-smoke.sh).
// Mirrors phase2-smoke.mjs: exits 0 only if every check passes.
const BASE = process.env.ADMIN_SMOKE_BASE ?? "http://127.0.0.1:3100";
const EMAIL = process.env.ADMIN_SMOKE_EMAIL ?? "admin@viduwa.dev";
const PASSWORD = process.env.ADMIN_SMOKE_PASSWORD ?? "";

let passed = 0;
let failed = 0;
function check(name, cond, detail = "") {
  if (cond) {
    passed++;
    console.log(`ok    ${name}`);
  } else {
    failed++;
    console.log(`FAIL  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

async function req(path, opts = {}) {
  const res = await fetch(`${BASE}${path}`, opts);
  let body = null;
  try {
    body = await res.json();
  } catch {
    body = null;
  }
  return { status: res.status, body, headers: res.headers };
}

const auth = (token) => ({ Authorization: `Bearer ${token}` });
const json = (extra) => ({ "Content-Type": "application/json", ...extra });

// ---- 1. Auth trust boundary ------------------------------------------------
const bad = await req("/v1/admin/auth/login", {
  method: "POST",
  headers: json(),
  body: JSON.stringify({ email: EMAIL, password: "definitely-wrong" }),
});
check("login rejects wrong password (401)", bad.status === 401 && bad.body?.error?.code === "ADMIN_INVALID");

const noToken = await req("/v1/admin/overview");
check("overview requires token (401)", noToken.status === 401);

const garbage = await req("/v1/admin/overview", { headers: auth("not-a-jwt") });
check("overview rejects garbage token (401)", garbage.status === 401);

// ---- 2. Login ---------------------------------------------------------------
const login = await req("/v1/admin/auth/login", {
  method: "POST",
  headers: json(),
  body: JSON.stringify({ email: EMAIL, password: PASSWORD }),
});
check("login succeeds", login.status >= 200 && login.status < 300 && typeof login.body?.token === "string");
const token = login.body?.token ?? "";

// ---- 3. Overview ------------------------------------------------------------
const ov = await req("/v1/admin/overview", { headers: auth(token) });
check("overview 200 with verdict counts", ov.status === 200 && ["AUTHENTIC", "PENDING", "TAMPERED"].every((k) => k in (ov.body?.verdicts ?? {})));
check("overview has per-role activity", Array.isArray(ov.body?.activity_by_role));
check("overview has per-day trend (14d)", ov.body?.batches_per_day?.length === 14);
check("overview has district analytics", Array.isArray(ov.body?.districts));

// ---- 4. Users ---------------------------------------------------------------
const users = await req("/v1/admin/users", { headers: auth(token) });
check("users list 200", users.status === 200 && Array.isArray(users.body?.users));
const first = users.body?.users?.[0];

const farmers = await req("/v1/admin/users?role=FARMER", { headers: auth(token) });
check(
  "user role filter works",
  farmers.status === 200 && farmers.body.users.every((u) => u.roles.includes("FARMER")),
);

const suspended = await req("/v1/admin/users?status=suspended", { headers: auth(token) });
check("user status filter works", suspended.status === 200 && suspended.body.users.every((u) => u.is_active === false));

if (first) {
  const detail = await req(`/v1/admin/users/${first.id}`, { headers: auth(token) });
  check("user detail 200 with farms", detail.status === 200 && Array.isArray(detail.body?.farms));

  // Suspend → verify flag → restore. Audit rows must appear for both.
  const susp = await req(`/v1/admin/users/${first.id}/status`, {
    method: "PATCH",
    headers: json(auth(token)),
    body: JSON.stringify({ is_active: false }),
  });
  check("suspend user 200", susp.status === 200 && susp.body?.is_active === false);
  const after = await req(`/v1/admin/users?status=suspended`, { headers: auth(token) });
  check("suspended user appears in filter", after.body.users.some((u) => u.id === first.id));
  const restore = await req(`/v1/admin/users/${first.id}/status`, {
    method: "PATCH",
    headers: json(auth(token)),
    body: JSON.stringify({ is_active: true }),
  });
  check("reactivate user 200", restore.status === 200 && restore.body?.is_active === true);

  // Role add + last-role guard + remove.
  const current = users.body.users.find((u) => u.roles.length === 1) ?? first;
  const add = await req(`/v1/admin/users/${current.id}/roles`, {
    method: "POST",
    headers: json(auth(token)),
    body: JSON.stringify({ role: "COLLECTOR" }),
  });
  check("add role 2xx", add.status >= 200 && add.status < 300 && add.body?.roles?.includes("COLLECTOR"));
  const rm = await req(`/v1/admin/users/${current.id}/roles/COLLECTOR`, {
    method: "DELETE",
    headers: auth(token),
  });
  check("remove role 200", rm.status === 200 && !rm.body?.roles?.includes("COLLECTOR"));
  const soleRole = (add.status === 200 ? rm.body?.roles : current.roles) ?? [];
  if (soleRole.length >= 1) {
    const last = await req(`/v1/admin/users/${current.id}/roles/${soleRole[0]}`, {
      method: "DELETE",
      headers: auth(token),
    });
    check("last-role guard (400 LAST_ROLE)", last.status === 400 && last.body?.error?.code === "LAST_ROLE");
  }
}

// ---- 5. Batches + verdicts --------------------------------------------------
const batches = await req("/v1/admin/batches", { headers: auth(token) });
check("batches list 200 with verdicts", batches.status === 200 && batches.body.batches.every((b) => ["AUTHENTIC", "PENDING", "TAMPERED"].includes(b.verdict)));

const tampered = await req("/v1/admin/batches?verdict=TAMPERED", { headers: auth(token) });
check("verdict filter works", tampered.status === 200 && tampered.body.batches.every((b) => b.verdict === "TAMPERED"));

const byRole = await req("/v1/admin/batches?role=EXPORTER", { headers: auth(token) });
check("holder-role filter works", byRole.status === 200 && byRole.body.batches.every((b) => b.current_holder_role === "EXPORTER"));

const one = batches.body?.batches?.[0];
if (one) {
  const detail = await req(`/v1/admin/batches/${one.batch_no}`, { headers: auth(token) });
  check(
    "batch detail by batch_no with chain + verdict",
    detail.status === 200 && detail.body?.verification?.verdict && Array.isArray(detail.body?.chain?.events ?? detail.body?.chain),
  );
}

// ---- 6. CSV export ----------------------------------------------------------
const csv = await fetch(`${BASE}/v1/admin/batches?format=csv`, { headers: auth(token) });
const csvText = await csv.text();
check("csv export content-type + header row", csv.status === 200 && csv.headers.get("content-type").includes("text/csv") && csvText.startsWith("batch_no,status,verdict"));

// ---- 7. Anchors + audit -----------------------------------------------------
const anchors = await req("/v1/admin/analytics/anchors", { headers: auth(token) });
check("anchors 200 with awaiting count", anchors.status === 200 && "events_awaiting_anchor" in anchors.body);

const audit = await req("/v1/admin/analytics/audit", { headers: auth(token) });
check("audit 200 and records today's admin actions", audit.status === 200 && audit.body.entries.some((e) => e.action === "ADMIN_LOGIN"));

const auditFiltered = await req("/v1/admin/analytics/audit?action=USER_SUSPENDED", { headers: auth(token) });
check("audit action filter works", auditFiltered.status === 200 && auditFiltered.body.entries.every((e) => e.action === "USER_SUSPENDED"));

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);

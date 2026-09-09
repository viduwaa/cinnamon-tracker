/**
 * Phase-2 smoke test against the configured Neon branch (.env).
 * Exercises: register → farm → harvest → transfer → accept → P2 process
 * (custom rename) → old-number alias lookup → exporter lot (merge 2) →
 * lot detail with origin chains → public verify (alias + lot).
 * Safe to re-run: unique mobiles/numbers per run.
 */
const BASE = process.env.SMOKE_BASE ?? "http://127.0.0.1:3100";
const stamp = Date.now().toString().slice(-8);
let failures = 0;

/** Client-generated UUIDv7 (API requires the v7 shape). */
function uuidv7() {
  const ts = Date.now();
  const hex = ts.toString(16).padStart(12, "0");
  const rnd = crypto.getRandomValues(new Uint8Array(10));
  const r = [...rnd].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-7${r.slice(0, 3)}-8${r.slice(3, 6)}-${r.slice(6, 18)}`;
}

function check(name, cond, extra = "") {
  if (cond) console.log(`  ok  ${name}`);
  else {
    failures++;
    console.log(`FAIL  ${name} ${extra}`);
  }
}

async function api(method, path, token, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(body && method !== "GET" ? { "idempotency-key": `smoke-${stamp}-${Math.random().toString(36).slice(2, 8)}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  return { status: res.status, json };
}

(async () => {
  // ---------- users ----------
  const farmer = (await api("POST", "/v1/auth/register", null, {
    name: `Smoke Farmer ${stamp}`, mobile: `+9477${stamp.slice(0, 7)}`, roles: ["FARMER"], preferred_lang: "en",
  })).json;
  const farmerTok = (await api("POST", "/v1/auth/otp/verify", null, {
    mobile: `+9477${stamp.slice(0, 7)}`, code: process.env.OTP_BYPASS_CODE ?? "000000",
  })).json.token;
  const proc = (await api("POST", "/v1/auth/register", null, {
    // Multi-role processor: farmer hands to L1, then the same user switches
    // holding role to L2 for grinding (self-transfer is the role switch).
    name: `Smoke P2 ${stamp}`, mobile: `+9478${stamp.slice(0, 7)}`, roles: ["PROCESSOR_L1", "PROCESSOR_L2"], preferred_lang: "en",
  })).json;
  const procTok = (await api("POST", "/v1/auth/otp/verify", null, {
    mobile: `+9478${stamp.slice(0, 7)}`, code: process.env.OTP_BYPASS_CODE ?? "000000",
  })).json.token;
  const exp = (await api("POST", "/v1/auth/register", null, {
    name: `Smoke Exporter ${stamp}`, mobile: `+9479${stamp.slice(0, 7)}`, roles: ["EXPORTER"], preferred_lang: "en",
  })).json;
  const expTok = (await api("POST", "/v1/auth/otp/verify", null, {
    mobile: `+9479${stamp.slice(0, 7)}`, code: process.env.OTP_BYPASS_CODE ?? "000000",
  })).json.token;
  check("3 users registered + verified", Boolean(farmerTok && procTok && expTok));

  // ---------- farm + two harvest batches ----------
  const farm = (await api("POST", "/v1/farms", farmerTok, {
    id: uuidv7(), name: "Smoke Farm", area_code: "GM", size_value: 1.0, size_unit: "ACRE",
  })).json;
  check("farm created with farmer_code", farm?.farmer_code === "A", JSON.stringify(farm).slice(0, 140));
  if (!farm?.id) {
    console.log("SMOKE ABORT — no farm");
    process.exit(1);
  }

  const day = new Date().toISOString().slice(0, 10);
  // Unique per run: julian slot from the clock (changes every second), so
  // re-runs never collide on batches.batch_no UNIQUE.
  const jd = 100 + (Date.now() % 250);
  const slot = Number(stamp.slice(-2)) + 10; // 10..99 — 2-digit codes
  const mkBatch = (seq) => ({
    id: uuidv7(), farm_id: farm.id,
    batch_no: `GM-${String(jd).padStart(3, "0")}-${String(seq).padStart(2, "0")}-${new Date().getFullYear()}-FM-A-T`,
    harvest_type: "T", harvest_date: day, tree_count: 10, weight_kg: 50 + seq,
  });
  const b1 = mkBatch(90), b2 = mkBatch(91);
  const cb1 = await api("POST", "/v1/batches", farmerTok, b1);
  const cb2 = await api("POST", "/v1/batches", farmerTok, b2);
  check("2 harvest batches created", cb1.status === 201 && cb2.status === 201, JSON.stringify(cb1.json));

  // ---------- transfer both to the P2 processor, accept ----------
  for (const b of [b1, b2]) {
    const tr = await api("POST", `/v1/batches/${b.id}/transfer`, farmerTok, {
      to_user_id: proc.id, transfer_kind: "SALE", price_lkr: 1000,
    });
    check(`transfer ${b.batch_no}`, tr.status === 201 || tr.status === 200, JSON.stringify(tr.json));
  }
  // self-visible inbox for processor
  const inbox = (await api("GET", "/v1/inbox", procTok)).json;
  const inboxItems = inbox.data ?? inbox;
  check("processor inbox has 2", Array.isArray(inboxItems) && inboxItems.length === 2, JSON.stringify(inbox).slice(0, 120));
  for (const b of [b1, b2]) {
    const ac = await api("POST", `/v1/inbox/${b.id}/accept`, procTok);
    check(`accept ${b.batch_no}`, ac.status < 300, JSON.stringify(ac.json));
  }

  // Multi-role switch: self-transfer L1 → L2 (holding role change), accept.
  for (const b of [b1, b2]) {
    const sw = await api("POST", `/v1/batches/${b.id}/transfer`, procTok, {
      to_user_id: proc.id, to_role: "PROCESSOR_L2", transfer_kind: "HANDOFF",
    });
    check(`role switch to L2 ${b.batch_no}`, sw.status < 300, JSON.stringify(sw.json));
    const ac = await api("POST", `/v1/inbox/${b.id}/accept`, procTok);
    check(`re-accept as L2 ${b.batch_no}`, ac.status < 300, JSON.stringify(ac.json));
  }

  // ---------- P2 processing: one default /P2, one custom rename ----------
  const p1res = await api("POST", `/v1/batches/${b1.id}/process`, procTok, { output_weight_kg: 45.5 });
  check("P2 default suffix /P2", p1res.json?.batch_no === `${b1.batch_no}/P2`, JSON.stringify(p1res.json));

  const customNo = `GM-${String(jd).padStart(3, "0")}-92-${new Date().getFullYear()}-P2-SM${slot}`;
  const p2res = await api("POST", `/v1/batches/${b2.id}/process`, procTok, { output_weight_kg: 40, batch_no: customNo });
  check("P2 custom rename applied", p2res.json?.batch_no === customNo && p2res.json?.previous_batch_no === b2.batch_no, JSON.stringify(p2res.json));

  // old number still resolves (alias) for the chain member
  const aliasLookup = await api("GET", `/v1/batches/by-no/${encodeURIComponent(b2.batch_no)}`, procTok);
  check("OLD number resolves via alias", aliasLookup.status === 200 && aliasLookup.json?.batch_no === customNo, JSON.stringify(aliasLookup.json).slice(0, 140));
  const aliasChain = aliasLookup.json?.chain ?? [];
  check("RENAMED event on chain", aliasChain.some((e) => e.event_type === "RENAMED"), JSON.stringify(aliasChain.map((e) => e.event_type)));

  // P1 must not be able to rename (register a P1 processor quickly)
  await api("POST", "/v1/auth/register", null, { name: `Smoke P1 ${stamp}`, mobile: `+9476${stamp.slice(0, 7)}`, roles: ["PROCESSOR_L1"], preferred_lang: "en" });
  // (no P1 flow exercised — processor is L2; P1 guard is unit-level via DTO)

  // ---------- exporter receives both (transfer matrix P2→EXPORTER) ----------
  for (const b of [b1, b2]) {
    const holder = b === b1 ? b1.batch_no : customNo;
    const cur = await api("GET", `/v1/batches/${b.id}`, procTok);
    const tr = await api("POST", `/v1/batches/${b.id}/transfer`, procTok, {
      to_user_id: exp.id, transfer_kind: "SALE", price_lkr: 5000,
    });
    check(`P2→EXPORTER transfer ${holder}`, tr.status < 300, JSON.stringify(tr.json));
    const ac = await api("POST", `/v1/inbox/${b.id}/accept`, expTok);
    check(`exporter accepts ${holder}`, ac.status < 300, JSON.stringify(ac.json));
  }

  // ---------- exporter renumbering (grill Q3): default /EX ----------
  const renameRes = await api("POST", `/v1/batches/${b1.id}/rename`, expTok, {});
  // b1 is at …/P2 by now — /EX appends to the CURRENT number.
  check("exporter default rename /EX", renameRes.json?.batch_no === `${b1.batch_no}/P2/EX` && renameRes.json?.previous_batch_no === `${b1.batch_no}/P2`, JSON.stringify(renameRes.json));

  // ---------- exporter lot: merge both, one-step export ----------
  // 3-digit seq from a 900-value window on the clock — collisions across
  // runs are rare; on one, the LOT_NO_TAKEN assertions still verify the
  // conflict path, just re-run to get a clean pass.
  const lotSeq = 100 + (Date.now() % 899);
  const lotNo = `EX-${String(lotSeq).padStart(3, "0")}-${new Date().getFullYear()}-EXP-A`;
  const preview = await api("POST", "/v1/lots/preview", expTok, {
    batch_ids: [b1.id, b2.id], lot_no: lotNo, shipment_date: day,
  });
  check("lot preview ok (2 origins)", preview.json?.ok === true && preview.json?.batch_count === 2, JSON.stringify(preview.json));

  const lot = await api("POST", "/v1/lots", expTok, {
    batch_ids: [b1.id, b2.id], lot_no: lotNo, shipment_date: day,
    container_no: "MSKU1234567", destination_country: "DE", buyer_name: "Spice GmbH",
  });
  check("lot created EXPORTED", lot.json?.status === "EXPORTED" && lot.json?.total_weight_kg === 85.5, JSON.stringify(lot.json));

  const merged1 = await api("GET", `/v1/batches/${b1.id}`, procTok);
  check("source batch now MERGED", merged1.json?.status === "MERGED", JSON.stringify(merged1.json).slice(0, 100));

  const lotDetail = await api("GET", `/v1/lots/${lot.json.lot_id}`, expTok);
  check("lot detail has 2 origin chains", lotDetail.json?.origins?.length === 2, JSON.stringify(lotDetail.json).slice(0, 160));

  // duplicate lot number rejected
  const dupLot = await api("POST", "/v1/lots", expTok, {
    batch_ids: [b1.id], lot_no: lotNo, shipment_date: day,
  });
  check("duplicate lot_no → 409", dupLot.status === 409, JSON.stringify(dupLot.json));

  // ---------- public verify (no auth): alias + lot ----------
  const vAlias = await api("GET", `/verify/${encodeURIComponent(b2.batch_no)}`);
  check("public verify via OLD number works", vAlias.json?.batch_no === customNo && vAlias.json?.chain?.length > 0, JSON.stringify(vAlias.json).slice(0, 140));
  const vLot = await api("GET", `/verify/${encodeURIComponent(lotNo)}`);
  const lotEvents = vLot.json?.chain ?? [];
  check("lot verify: multi-origin flat chain", vLot.json?.batch_no === lotNo && lotEvents.some((e) => e.event_type === "EXPORTED") && lotEvents.some((e) => e.batch_no && e.batch_no !== lotNo), JSON.stringify(lotEvents.map((e) => [e.batch_no, e.event_type])));
  check("lot verify exposes origins[]", Array.isArray(vLot.json?.origins) && vLot.json.origins.length === 2, JSON.stringify(vLot.json?.origins ?? null).slice(0, 160));

  console.log(failures === 0 ? "\nSMOKE PASS" : `\nSMOKE FAIL (${failures})`);
  process.exit(failures === 0 ? 0 : 1);
})().catch((e) => {
  console.error("SMOKE ERROR", e);
  process.exit(1);
});

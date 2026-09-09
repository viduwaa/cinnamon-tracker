/**
 * Server-rendered public verify page. No template engine, no SPA — the
 * truth and its presentation ship in the same binary. JSON consumers use
 * the same endpoint with Accept: application/json (content negotiation in
 * verify.controller.ts).
 */

interface VerifyView {
  batch_no: string;
  verdict: string;
  anchors: Array<{
    network: string;
    tx_hash: string | null;
    anchored_at: string;
    status: string;
  }>;
  origin: {
    farm_name?: string;
    address?: string | null;
    district?: string;
    area_code?: string;
    size?: string;
    location?: { lat: number; lng: number } | null;
  } | null;
  /** Export lots only: one entry per merged source batch. */
  origins?: Array<{
    batch_no?: string;
    farm_name?: string | null;
    district?: string | null;
    weight_kg?: number;
  }>;
  chain: Array<{
    batch_no?: string;
    summary?: string;
    event_type: string;
    actor_name: string;
    actor_role: string;
    at: string;
    event_hash: string;
    anchored?: boolean;
    verified?: boolean;
  }>;
}

/** Minimal escaper — the payload is our own data, but user names are free text. */
function esc(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function shortHash(hash: unknown): string {
  const h = String(hash ?? "");
  return h.length > 20 ? `${h.slice(0, 10)}…${h.slice(-6)}` : h || "—";
}

function fmtWhen(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? iso
    : d.toLocaleString("en-GB", {
        day: "2-digit",
        month: "short",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
        timeZone: "Asia/Colombo",
      });
}

const VERDICT_META: Record<string, { label: string; color: string; icon: string }> = {
  AUTHENTIC: { label: "Authentic — blockchain verified", color: "#166534", icon: "✓" },
  PENDING: { label: "Verification pending", color: "#92400E", icon: "◔" },
  TAMPERED: { label: "Tampering detected", color: "#B91C1C", icon: "✕" },
};

/** Server-rendered verify page: verdict, origin, anchors, custody timeline. */
export function renderVerifyPage(v: VerifyView): string {
  const meta = VERDICT_META[v.verdict] ?? VERDICT_META.PENDING;
  const origin = v.origin;
  const originLocation = origin?.location
    ? `${origin.location.lat.toFixed(5)}, ${origin.location.lng.toFixed(5)}`
    : `District ${esc(origin?.district ?? origin?.area_code ?? "—")}`;
  const originMap =
    origin?.location
      ? `<iframe class="origin-map" src="https://maps.google.com/maps?q=${origin.location.lat},${origin.location.lng}&z=14&output=embed" loading="lazy" referrerpolicy="no-referrer-when-downgrade" title="Farm location map"></iframe>`
      : "";

  const anchorBlocks = v.anchors.length
    ? v.anchors
        .map(
          (a) => `
      <div class="card">
        <div class="anchor-head"><span class="ok">${esc(a.network)}</span> · ${esc(a.status)}</div>
        <div class="row"><span>Attestation</span><code>${esc(shortHash(a.tx_hash))}</code></div>
        <div class="row"><span>Anchored</span>${esc(fmtWhen(a.anchored_at))}</div>
      </div>`,
        )
        .join("")
    : `<p class="muted">Not yet anchored — the nightly job submits every event hash to OpenTimestamps calendars, which anchor to Bitcoin within ~24 h.</p>`;

  const events = v.chain
    .map(
      (e) => `
    <li>
      <div class="dot ${e.anchored ? "ok" : ""}"></div>
      <div class="ev">
        <div class="ev-title">${esc(e.summary ?? e.event_type)}</div>
        ${e.batch_no && e.batch_no !== v.batch_no ? `<div class="muted"><code>${esc(e.batch_no)}</code></div>` : ""}
        <div class="muted">${esc(e.actor_name)} · ${esc(e.actor_role)} · ${esc(fmtWhen(e.at))}</div>
        <code class="hash" title="${esc(e.event_hash)}">${esc(shortHash(e.event_hash))}</code>
        ${e.anchored ? '<span class="ok small">✓ anchored</span>' : ""}
      </div>
    </li>`,
    )
    .join("");

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Cinnamon Trace — ${esc(v.batch_no)}</title>
<style>
  :root { color-scheme: light; }
  * { box-sizing: border-box; margin: 0; }
  body { font: 16px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
         background: #FAF3E7; color: #2B1D12; padding: 24px 16px 48px; }
  main { max-width: 640px; margin: 0 auto; }
  .brand { display: flex; align-items: center; gap: 10px; margin-bottom: 18px; }
  .logo { width: 40px; height: 40px; border-radius: 12px; background: #8B4A2B;
          color: #FAF3E7; display: grid; place-items: center; font-size: 20px; }
  .brand b { font-size: 17px; } .brand span { display: block; font-size: 12px; color: #7A6A58; }
  .verdict { display: flex; gap: 12px; align-items: center; border-radius: 16px;
             padding: 16px; margin-bottom: 16px; border: 1px solid ${meta.color}33;
             background: ${meta.color}14; }
  .verdict .icon { width: 40px; height: 40px; border-radius: 999px; display: grid;
                   place-items: center; color: #fff; background: ${meta.color}; font-size: 20px; flex: none; }
  .verdict b { color: ${meta.color}; font-size: 17px; }
  .card { background: #FFFDF8; border: 1px solid #E8DCC8; border-radius: 14px;
          padding: 14px 16px; margin-bottom: 12px; }
  h2 { font-size: 15px; margin: 20px 0 8px; color: #4A2C17; }
  .row { display: flex; justify-content: space-between; gap: 12px; padding: 3px 0;
         font-size: 14px; }
  .row span:first-child { color: #7A6A58; }
  .card code { font-family: ui-monospace, monospace; font-size: 12px; }
  .origin-map { width: 100%; height: 200px; border: 0; border-radius: 10px; margin-top: 10px; }
  .muted { color: #7A6A58; font-size: 13.5px; }
  .ok { color: #166534; font-weight: 600; }
  .anchor-head { font-size: 13.5px; margin-bottom: 6px; }
  ol { list-style: none; padding: 0; }
  li { display: flex; gap: 12px; padding: 10px 0; border-bottom: 1px solid #E8DCC8; }
  li:last-child { border-bottom: 0; }
  .dot { width: 12px; height: 12px; border-radius: 999px; background: #D98E32;
         margin-top: 5px; flex: none; }
  .dot.ok { background: #4C7A34; }
  .ev-title { font-weight: 600; }
  .hash { display: inline-block; background: #F7E8D2; border-radius: 6px;
          padding: 1px 7px; margin-top: 4px; color: #4A2C17; }
  .small { font-size: 12px; margin-left: 8px; }
  .foot { margin-top: 22px; font-size: 12.5px; color: #7A6A58; text-align: center; }
</style>
</head>
<body>
<main>
  <div class="brand">
    <div class="logo">🌿</div>
    <div><b>Cinnamon Trace</b><span>farm-to-export provenance</span></div>
  </div>

  <div class="verdict">
    <div class="icon">${meta.icon}</div>
    <div><b>${esc(meta.label)}</b>
      <div class="muted">Batch <code>${esc(v.batch_no)}</code></div>
    </div>
  </div>

  ${
    origin
      ? `<div class="card">
           <div class="row"><span>Farm</span><b>${esc(origin.farm_name ?? "Farm")}</b></div>
           ${origin.address ? `<div class="row"><span>Address</span>${esc(origin.address)}</div>` : ""}
           <div class="row"><span>District</span>${esc(origin.district ?? origin.area_code ?? "—")}</div>
           ${origin.size ? `<div class="row"><span>Land size</span>${esc(origin.size)}</div>` : ""}
           <div class="row"><span>Location</span>${originLocation}</div>
           ${originMap}
         </div>`
      : ""
  }

  ${
    v.origins && v.origins.length
      ? `<div class="card">
           <div class="row"><span>Export lot</span><b>${v.origins.length} origin batch${v.origins.length === 1 ? "" : "es"}</b></div>
           ${v.origins
             .map(
               (o) =>
                 `<div class="row"><span><code>${esc(o.batch_no ?? "—")}</code></span>${esc(
                   [o.farm_name, o.district].filter(Boolean).join(" · ") || "—",
                 )}${o.weight_kg != null ? ` · ${esc(o.weight_kg)} kg` : ""}</div>`,
             )
             .join("")}
         </div>`
      : ""
  }

  <h2>Bitcoin anchors</h2>
  ${anchorBlocks}

  <h2>Chain of custody (${v.chain.length})</h2>
  <ol>${events}</ol>

  <p class="foot">Any party can recompute these SHA-256 hashes and independently
  verify the Bitcoin timestamps. This page reflects server truth at request time.</p>
</main>
</body>
</html>`;
}

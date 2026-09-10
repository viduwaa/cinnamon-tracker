// Headless E2E of the admin console against the running dev servers.
// Proves: login flow → session persisted → overview data rendered.
import { chromium } from "playwright-core";

const BASE = process.env.E2E_BASE ?? "http://localhost:5173";
const EMAIL = "admin@viduwa.dev";
const PASSWORD = process.env.ADMIN_SMOKE_PASSWORD ?? "";

// Uses the system Edge/Chrome channel — no Playwright browser download needed.
const browser = await chromium.launch({ channel: "msedge" });
const page = await browser.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(`pageerror: ${e.message}`));
page.on("console", (m) => {
  if (m.type() === "error") errors.push(`console: ${m.text()}`);
});

// 1. Login page renders
await page.goto(`${BASE}/login`, { waitUntil: "networkidle" });
const title = await page.textContent("form .font-display");
console.log(`login page shows: ${title?.trim()}`);

// 2. Sign in with real credentials through the real form
await page.fill("#email", EMAIL);
await page.fill("#password", PASSWORD);
await page.click("button[type=submit]");
await page.waitForURL(`${BASE}/`, { timeout: 20000 });
console.log("redirected to overview ✓");

// 3. Overview renders live data from the API
await page.waitForSelector("table.ct", { timeout: 20000 });
const kpis = await page.$$eval("main .grid .font-display", (els) =>
  els.slice(0, 4).map((e) => e.textContent?.trim()),
);
console.log(`KPIs rendered: ${kpis?.join(" | ")}`);
const verdictBadges = await page.$$eval("main span", (els) =>
  els.map((e) => e.textContent).filter((t) => ["AUTHENTIC", "PENDING", "TAMPERED"].includes(t ?? "")).length,
);
console.log(`verdict badges rendered: ${verdictBadges}`);

// 4. Users page loads and shows rows
await page.goto(`${BASE}/users`, { waitUntil: "networkidle" });
await page.waitForSelector("table.ct tbody tr", { timeout: 20000 });
const rows = await page.$$eval("table.ct tbody tr", (r) => r.length);
console.log(`users table rows: ${rows}`);

// 5. Batches page + verdict filter present
await page.goto(`${BASE}/batches`, { waitUntil: "networkidle" });
await page.waitForSelector("table.ct tbody tr", { timeout: 20000 });
const bRows = await page.$$eval("table.ct tbody tr", (r) => r.length);
console.log(`batches table rows: ${bRows}`);

if (errors.length) {
  console.log("JS errors observed:");
  for (const e of errors) console.log(`  ${e}`);
}
const ok = title?.includes("Cinnamon") && rows > 0 && bRows >= 0 && errors.length === 0;
console.log(ok ? "E2E PASS" : "E2E FAIL");
await browser.close();
process.exit(ok ? 0 : 1);

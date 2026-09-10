# Cinnamon Trace — Presenter Script
**Tone:** energetic, sharp, honest · **Length:** ~10 minutes · **Deck:** docs/presentation/presentation.html (10 slides)

Delivery key: **bold** = punch the line · / = short beat · ↑ = lift energy · ↓ = slow down for weight

---

## SLIDE 1 — The Promise *(~45s)*

Good morning, everyone. ↑

Let me start with a question. When you buy "Pure Ceylon Cinnamon" in Europe — how do you *know* it's Ceylon? **You don't. You trust a sticker.**

*(beat)*

We built the thing that replaces trust with proof. **Cinnamon Trace** — every quill of cinnamon, provably from its farm.

Here's the dossier on the right — this is real, from our running system. One export lot. Five farms. Twenty-three custody events. And a Bitcoin anchor that says: *this record has never been touched.*

The whole journey — from a smallholder's plot in Galle to a container in Hamburg — **with a mathematical receipt attached to every single handoff.** That's what we're here to show you.

---

## SLIDE 2 — The Stakes *(~60s)*

Now — why now? Because Europe just changed the rules on everyone.

The EU Deforestation Regulation. ↑ For every spice shipment entering the Union, you must prove — with **exact GPS coordinates** — which plots grew it, and that none of it touched deforested land.

And look at the number. ↓ **Four percent.** Of your *annual EU turnover*. That's the maximum fine. Before they impound your container. Before the buyer walks.

For a small exporter — one detained shipment is an extinction event. *(beat)* Paper logbooks? **Legally worthless** at the border. Done. Finished.

But here's why I'm excited, not scared. ↓ We turned this into an advantage. The farmer drops **one pin** at the farm gate — once — and it's attached to every harvest from that plot, forever. Our exporters generate the entire customs dossier in **one click.** And verified origin? That's not just compliance — that's a **brand.** That's premium pricing.

Regulation is the entry fee. **Proof is the weapon.**

---

## SLIDE 3 — The Route *(~60s)*

So how does cinnamon actually move? Five hands. One unbroken thread. Watch the flow on the path.

**Farmer** — pins the plot, logs the harvest. The batch number is minted *on the phone* — works with zero signal.

**Collector** — buys, carries. Number doesn't change — custody moves, history stays.

**Processors** — peeling, quilling, grinding. Every yield number recorded. And this part is **brand new — we shipped it this week.** Processing stages are live.

**Exporter** — merges batches into one container lot. One QR code… with every farm inside it.

**And the buyer.** Scans the bag. Verdict, origin map, cryptographic proof — **in one second.** No app download. Nothing to install.

Five hands — and between every pair of them, a mathematically sealed event. / Now — what happens when there's no signal in that village?

---

## SLIDE 4 — Offline First *(~60s)*

Here's the thing people get wrong about "rural software." They build for the demo, not for the *field*. ↑

Signal in cinnamon-growing villages? **Sometimes. Sometimes not.** So we built for "not."

Everything lands on the phone first — a real database, on the device. The farmer saves a harvest offline, and look at the screen — it's right there. Number minted. QR ready. **Printed on the bag before the truck leaves the village.**

See that yellow banner? *"Two events queued — will sync automatically."* That's the outbox. Think of it like WhatsApp's clock — your data is safe locally and sends when the network returns.

And the engineering underneath handles the ugly cases: retries with backoff, idempotency keys — **a retry can never double-sell a batch** — and if two phones generate the same number offline, the system heals it automatically.

Farmers don't wait for signal. **Neither does our software.**

---

## SLIDE 5 — The Number *(~60s)*

Now my favorite slide — this number is doing a lot of work. Let's read it together.

**GM** — Galle district. **172** — Julian day — day 172 of the year. **01** — the first batch that farm harvested *that day*. **2026** — the year. **FM-A** — that farmer's permanent code. **T** — trees, not quills.

Every harvest on Earth could carry a number like this, and there'd never be a duplicate — it's a fingerprint for a bag of cinnamon.

Then processing happens — see the stage tag attach? **/P1**, **/P2**. And here's the clever part: ↓ a processor *may* rename their batch — some buyers want custom codes — but the farm link **never** breaks. Every old number keeps resolving, forever. We keep an alias table — the original QR on a printed label still verifies even after three renames.

And at the end — the merge. ↑ Three farms, 157 kilos, **one container**. One lot number. And one QR that opens the *complete* story of every farm inside. That's what European customs actually needs.

---

## SLIDE 6 — Blockchain, Part 1 *(~75s)* ← *the heart of the deck*

Okay. ↑ Everyone hears "blockchain" and thinks: bitcoin wallets, crypto bros, gas fees. *(wave it off)* **Forget all of that.** What we use is simpler and smarter. Two ideas. No coins. No wallets.

**Idea one.** Every event in our system gets a fingerprint — a SHA-256 hash. Look at the receipts on the left. Harvested → fingerprint. Sold → fingerprint. Processed → fingerprint.

But here's the trick: ↓ **each fingerprint is made *from* the previous fingerprint.** They're stapled together. With math.

So — someone breaks into the database and changes "120 kilos" to "90." Sounds easy, right? ↓ **The moment they do it, that receipt's fingerprint changes.** Which no longer matches the next receipt. Which no longer matches the next. The whole chain *snaps* — and the system screams 🔴 **TAMPERED**.

You can't edit history. **Not because someone's watching — because the math won't hold.**

And where does this live? Right column — an ordinary PostgreSQL database. Append-only: new facts are *new rows*; nothing is ever edited. And anyone can verify it — our verify page recomputes the entire chain on every scan.

That's idea one. / "But wait," you say — "it's still *your* server. What if *you* lie?" ↓ Love that question. **Slide seven.**

---

## SLIDE 7 — Blockchain, Part 2 *(~60s)*

Exactly. Our server *could* lie. Reweight every event, re-staple every hash — internally, it'd look perfect.

So once a day, at midnight, we do something beautiful. ↑

All the day's event fingerprints get combined — paired, paired again, paired again — down into **one single hash**. One line of text that mathematically represents *the entire day*. That's the Merkle root.

And we write that one line into **the Bitcoin blockchain** — through a free protocol called OpenTimestamps.

Why Bitcoin? ↓ Because it's the biggest, oldest, most tamper-proof **notice board on the planet.** Once today's fingerprint is written there, it's *carved*. Our server can't disagree with it anymore. **Nobody's server can.**

And the question everyone asks: *what do you write on Bitcoin? The farmers' data??* ↓ No. **32 bytes. One fingerprint per day.** That's it. The data stays private; the *proof* goes public.

Cost? *(hold up hand)* **Zero.** No wallets. No coins. No gas fees. For anyone. Ever. It confirms within about a day — and from that moment, not even *we* can cheat.

---

## SLIDE 8 — The Verdicts *(~45s)*

So every scan in the world gets one of three answers. And this is interactive — let's click.

🟢 **AUTHENTIC** — every fingerprint recomputes perfectly, *and* Bitcoin confirms the timestamp. This batch's story is mathematically intact. This is what a European inspector wants to see — and it's checkable **without trusting us at all.** The proof tools are open-source and portable.

🟡 **PENDING** — chain is intact, record is live, Bitcoin stamp comes tonight. Fresh harvest looks like this for its first day. *Honest* pending.

And 🔴 **TAMPERED** — someone edited a record. Weight, date, GPS — doesn't matter. The math catches it, names the event where it broke, and raises the alarm.

Three verdicts. **Zero opinions.** Just math.

---

## SLIDE 9 — Proof *(~45s)*

Now, everything I've said — you don't have to believe me. ↓ Because it's *tested*.

**78 automated tests, all green** — hash chains, Merkle proofs, verdicts, OTP, transfer rules, the processing engine.

**Twenty-nine out of twenty-nine** — a complete journey: register, harvest, sell, process, renumber, merge, export, public verify — executed against the *real production cloud database*, not a mock.

We've received **real Bitcoin proofs** through the live OpenTimestamps network — independently verifiable, right now.

And a **signed release APK** is built — this is software you can install today. Everything on the roadmap last quarter — processing, renaming, container lots — is *live*. **This is not a slide deck. It's a running system.**

---

## SLIDE 10 — Close *(~45s)*

So let's land this. ↓

Compliance is the entry fee — and we've paid it. But the *prize* is bigger:

**Plus fifteen to twenty-five percent.** That's the premium for verified Ceylon provenance — with the proof attached to every bag. **One hundred percent EU market access** — dossiers per shipment, border risk gone. And **zero** — *dollar zero* — ongoing integrity cost. The trust layer is free. Forever.

The platform is built. Tested. Running. ✓ The integrity layer is proven. ✓ Dossiers generate in one click. ✓

**What it needs now is a first real harvest season.** ↑ And that's the ask — partners for the first season, in Galle and Matara, where the cinnamon is best.

*(beat, smile)*

Sri Lanka grows the best cinnamon on Earth. **Now we can prove it.** Thank you. 🌿

---

## Q&A ammo (likely questions)

- **"Why not Hyperledger / a private chain?"** — A chain we control proves nothing to a stranger; the whole point is a notary we *don't* control. Public Bitcoin anchoring is cheaper than any private chain to run (free) and stronger (global consensus). The schema has network enums — we can add chains later without touching the app.
- **"What if the farmer's phone is lost offline for a week?"** — Data stays in SQLite, queue persists, syncs when back. Numbers are date+counter based, collisions heal via 409-regenerate. Nothing is lost.
- **"Can two exporters collide on lot numbers?"** — Lot numbers carry the exporter's personal code; uniqueness is enforced by the database, and the client regenerates on conflict automatically.
- **"GDPR / farmer privacy?"** — Bitcoin stores only a 32-byte fingerprint. Verify pages honor each farmer's location-privacy choice (exact / district / hidden).
- **"What does 'tampered' actually trigger?"** — The verdict appears on the public page and in-app immediately; the audit log records who last touched it. Authenticity business stops until investigated.
- **"Cost at scale?"** — Database is usage-based (Neon scales to zero), anchoring is free, hosting is one small server. Thousands of batches/day ≈ a few dollars a month.

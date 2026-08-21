# Cinnamon Trace — Mobile Wireframes & Flows (v0.1)

Design principles: Sinhala-first labels, large touch targets, one question per
screen, number-only keypads, offline-first, every success ends in a big
confirmation with QR + WhatsApp share.

App name below is a placeholder — call it **"Cinnamon Trace"** until branding.

---

## Navigation shell (all roles)

```
┌────────────────────────────┐
│ [👤 Sunil]  Acting as:      │   ← role chips when user has >1 role
│  ● Farmer  ○ P1  ○ Collector│     tap to switch scope
├────────────────────────────┤
│                            │
│        SCREEN BODY         │
│                            │
├────────────────────────────┤
│  🏠       📦       📷      │
│  මුල්    බැච්       QR     │
│  Home   Batches  Scan/QR  │
└────────────────────────────┘
   FAB:  [ ＋ New Batch ]  — floating above nav bar, always visible.
   Profile (⚙) reached from Home header.
```

- One app, one login. Role chips scope what Home shows and what actions are
  available; bottom nav stays constant (3 tabs + FAB keeps it simple for
  low-literacy users).
- Incoming transfers surface as a banner on Home: "📥 2 batches waiting".

---

## Registration (3 screens)

```
┌────────────────────────────┐  ┌────────────────────────────┐
│        Cinnamon Trace      │  │     Enter the 6-digit code │
│                            │  │     sent to +94 77 123…    │
│  Your name                 │  │                            │
│  ┌──────────────────────┐  │  │   [ _ _ _ _ _ _ ]          │
│  │ Sunil Perera         │  │  │                            │
│  └──────────────────────┘  │  │   Resend in 0:42           │
│  Mobile number             │  │                            │
│  ┌──────────────────────┐  │  │        [ Verify ]          │
│  │ +94 77 123 4567      │  │  └────────────────────────────┘
│  └──────────────────────┘  │
│  Email (optional)          │
│  ┌──────────────────────┐  │
│  │                      │  │
│  └──────────────────────┘  │
│                            │
│  I am a: (pick any)        │
│  ┌─────────┐ ┌─────────┐  │
│  │✓ Farmer │ │Processor│  │
│  │  ගොවියා │ │  L1     │  │
│  └─────────┘ └─────────┘  │
│  ┌─────────┐ ┌─────────┐  │
│  │Collector│ │Processor│  │
│  │         │ │  L2     │  │
│  └─────────┘ └─────────┘  │
│  ┌─────────────────────┐  │
│  │      Exporter       │  │
│  └─────────────────────┘  │
│        [ Continue ]        │
└────────────────────────────┘
```

After verify → straight into the role's Home. Farmer with no farm yet is
guided to "Add your farm first" (blocking wizard).

---

## Farmer Home

```
┌────────────────────────────┐
│ ☀ Ayubowan, Sunil!         │
│ ┌────────────────────────┐ │
│ │ 🌳 My Farms        (2) │ │
│ │ Home Garden · 1.5 acres│ │
│ │ Walpita, Galle     [📍]│ │
│ └────────────────────────┘ │
│ ┌────────────────────────┐ │
│ │ 📦 Active batches   (3)│ │
│ │ GM-172-01-2026-FM-A-T  │ │
│ │ 120 kg · Trees · Aug 17│ │
│ │ status: HARVESTED      │ │
│ ├────────────────────────┤ │
│ │ GM-170-02-2026-FM-A-Q  │ │
│ │ 40 kg · Quills · Aug 15│ │
│ │ status: SOLD ✓         │ │
│ └────────────────────────┘ │
│                            │
│      [ ＋ New Harvest ]    │
└────────────────────────────┘
```

---

## Harvest wizard (5 steps, one question each)

```
Step 1 — Farm            Step 2 — Date           Step 3 — Type
┌──────────────────┐    ┌──────────────────┐   ┌──────────────────┐
│ Which farm?      │    │ Harvest date     │   │ How harvested?   │
│ ┌──────────────┐ │    │ ┌──────────────┐ │   │ ┌──────────────┐ │
│ │🏡 Home Garden│ │    │ │ 📅 Today     │ │   │ │ 🌳  Trees    │ │
│ │   ✓ selected │ │    │ │ Aug 17, 2026 │ │   │ │   (T)        │ │
│ ├──────────────┤ │    │ └──────────────┘ │   │ ├──────────────┤ │
│ │🏡 New plot   │ │    │  [change date…]  │   │ │ 🪶  Quills   │ │
│ └──────────────┘ │    │                  │   │ │   (Q)        │ │
│  [+ Add new farm]│    │    [ Next ]      │   │ └──────────────┘ │
└──────────────────┘    └──────────────────┘   │    [ Next ]      │
                                                └──────────────────┘
Step 4 — Numbers         Step 5 — Review + confirm
┌──────────────────┐    ┌──────────────────────┐
│ Tree count       │    │ 🌳 Home Garden       │
│ ┌──────────────┐ │    │ Aug 17, 2026 · Trees │
│ │  45          │ │    │ 45 trees · 120.5 kg  │
│ └──────────────┘ │    │                      │
│ Weight (kg)      │    │ Batch number will be:│
│ ┌──────────────┐ │    │ GM-172-01-2026-FM-A-T│
│ │  120.5       │ │    │                      │
│ └──────────────┘ │    │      [ Confirm ✓ ]   │
│    [ Next ]      │    └──────────────────────┘
└──────────────────┘
```

Works fully offline: batch number computed on device (area code + Julian day +
daily sequence + farmer code + T/Q). Syncs when online; server confirms or
asks for next sequence on collision.

---

## Batch created — confirmation

```
┌────────────────────────────┐
│          🎉 Saved!         │
│                            │
│   GM-172-01-2026-FM-A-T    │   ← huge, readable
│   ┌────────────────────┐   │
│   │  ▓▓▓ ▓ ▓▓▓ ▓▓ ▓▓▓  │   │   ← QR code
│   │  ▓ ▓▓ ▓▓▓ ▓ ▓▓ ▓   │   │
│   │  ▓▓▓▓▓ ▓ ▓▓▓▓ ▓▓   │   │
│   └────────────────────┘   │
│                            │
│  [ 📤 Share on WhatsApp ]  │
│  [ 💰 Sell / Hand over ]   │
│  [ Done ]                  │
└────────────────────────────┘
```

---

## Sell / hand over (any holder)

```
Step 1 — Who gets it?        Step 2 — Confirm
┌──────────────────────┐    ┌──────────────────────┐
│ 🔍 Search mobile or  │    │ Sell to:             │
│    name…             │    │ Nimal Fernando       │
│ ┌──────────────────┐ │    │ PROCESSOR_L1         │
│ │👤 Nimal F.  P1   │ │    │ +94 71 222 3344      │
│ │👤 Kumar C.  CL   │ │    │                      │
│ │👤 Export Co EX   │ │    │ Batch: GM-172-01…    │
│ └──────────────────┘ │    │ 120.5 kg             │
│  …or [ 📷 Scan QR ]  │    │ Kind: SALE / HANDOFF │
│                      │    │ Price: [ 45,000 ] LKR│
│    [ Next ]          │    │   [ Confirm Sale ✓ ] │
└──────────────────────┘    └──────────────────────┘
```

- Recipient list is pre-filtered by the transfer matrix (farmer sees only
  Collectors and L1 processors, etc.).
- Collector transfers show no batch-number field — number never changes.

---

## Collector / Processor inbox & processing

```
Inbox banner → Inbox screen:
┌────────────────────────────┐
│ 📥 Incoming                │
│ ┌────────────────────────┐ │
│ │ GM-172-01-2026-FM-A-T  │ │
│ │ from Sunil (Farmer)    │ │
│ │ 120.5 kg · SALE        │ │
│ │ [ Accept ]  [ View ]   │ │
│ └────────────────────────┘ │
└────────────────────────────┘

Processor — batch detail + process action:
┌────────────────────────────┐
│ GM-172-01-2026-FM-A-T      │
│ ▼ Origin chain (upward)    │
│   🌳 Sunil · Farm · Aug 17 │
│   → You received Aug 18    │
│                            │
│ Output weight: [ 98.0 ] kg │
│ Process: [Quilling ▾]      │
│ New batch no (auto):       │
│ GM-172-01-2026-FM-A-T/P1   │
│  (P1 cannot edit this)     │
│      [ Process ✓ ]         │
└────────────────────────────┘
```

P2 sees the same screen but with an editable "New batch no" field
(validation pattern enforced, parent link created regardless).

---

## Exporter — lot builder

```
┌────────────────────────────┐
│ Build export lot           │
│ ☐ GM-172-01-2026-FM-A-T/P1 │
│ ☑ GM-170-02-2026-FM-B-Q/P1 │
│ ☑ GM-169-01-2026-FM-C-T/P1 │
│                            │
│ Lot no: EX-001-2026-EXP-A  │
│ Ship date: [Sep 10]        │
│ Destination: [Germany ▾]   │
│ Buyer: [Spice GmbH]        │
│                            │
│ 2 batches · 3 origin farms │
│      [ Create Lot ✓ ]      │
└────────────────────────────┘
```

Result screen shows the lot QR — scanning it reveals **all** origin chains.

---

## Public verification page (QR scan, any browser)

```
https://verify.cinnamontrace.example/GM-172-01-2026-FM-A-T

┌──────────────────────────────────────┐
│ ✅ AUTHENTIC — verified on blockchain│
│    Polygon · tx 0xabc… · Aug 21      │
├──────────────────────────────────────┤
│ ORIGIN                               │
│ 🌳 Home Garden, Galle district       │
│    Harvested Aug 17, 2026            │
│    45 trees · 120.5 kg · Trees       │
│    by Sunil P.                       │
├──────────────────────────────────────┤
│ CHAIN OF CUSTODY                     │
│ 1. Harvested — Farmer, Aug 17   🔗✓  │
│ 2. Sold → Nimal (P1), Aug 18    🔗✓  │
│ 3. Quilled → 98 kg, Aug 20      🔗✓  │
├──────────────────────────────────────┤
│ Each 🔗 = hash verified against      │
│ anchored blockchain root.            │
│ Languages: EN | සිං | தமிழ்          │
└──────────────────────────────────────┘
```

No login. Farmer's exact coordinates shown only if farm privacy level is
`EXACT`; otherwise district-level text.

---

## Batch state machine

```
                          ┌────────────┐
        farmer harvest ──▶│ HARVESTED  │
                          └─────┬──────┘
                       transfer │ accept
                          ┌─────▼──────┐        ┌──────────┐
                          │ IN_TRANSIT │───────▶│ RECEIVED │
                          └────────────┘        └─────┬────┘
                                        process / re- │ receive own
                                                  ┌───▼──────┐
                                                  │PROCESSED │◀─┐ (loop: transfer →
                                                  └───┬──────┘     process again)
                            exporter merge            │
                          ┌───────────┐         ┌─────▼─────┐
                          │  MERGED   │◀────────│ EXPORTED  │
                          └───────────┘         └───────────┘
                          (source batch         (lot leaves country;
                           frozen)               chain public via QR)
```

- `MERGED` source batches stay readable (upward chain intact) but can never
  be transferred or processed again.
- A batch reverts to `RECEIVED` if a transfer is rejected by the recipient
  within the acceptance window.

---

## Accessibility & localization checklist

- Sinhala default; Tamil + English toggle in onboarding and profile.
- Minimum 16sp body text, 48dp touch targets, high-contrast palette.
- Icon + label on every button (never icon-only).
- Number inputs: numeric keyboard, decimal point for weight only.
- All flows testable with TalkBack; error messages announced.
- Works on Android Go / 2GB RAM devices; app target < 25 MB.
- Offline banner: "No internet — saved on this phone, will sync" (never block).

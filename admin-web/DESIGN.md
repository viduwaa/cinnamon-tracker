---
version: alpha
name: Cinnamon Harvest Admin
description: Government oversight console for Cinnamon Trace — the mobile app's warm, earthy Cinnamon Harvest system adapted for a data-dense government dashboard.
colors:
  primary: "#8B4A2B"
  secondary: "#4A2C17"
  tertiary: "#D98E32"
  neutral: "#FAF3E7"
  paper: "#FFFDF8"
  ink: "#2B1D12"
  faded: "#7A6A58"
  line: "#E8DCC8"
  leaf: "#4C7A34"
  leaf-dark: "#3D6329"
  leaf-soft: "#E7EFDD"
  clay: "#B4452F"
  clay-dark: "#A23522"
  clay-soft: "#F6E0DA"
  quill: "#D98E32"
  quill-soft: "#F7E8D2"
  bark: "#4A2C17"
typography:
  h1:
    fontFamily: Baloo 2
    fontSize: 1.75rem
    fontWeight: 700
    lineHeight: 1.2
  h2:
    fontFamily: Baloo 2
    fontSize: 1.25rem
    fontWeight: 700
    lineHeight: 1.3
  body-lg:
    fontFamily: Noto Sans
    fontSize: 1rem
    fontWeight: 400
    lineHeight: 1.5
  body-md:
    fontFamily: Noto Sans
    fontSize: 0.875rem
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: Noto Sans
    fontSize: 0.75rem
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "0.04em"
  metric:
    fontFamily: Baloo 2
    fontSize: 2rem
    fontWeight: 700
    lineHeight: 1.1
rounded:
  sm: 8px
  md: 12px
  lg: 18px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.paper}"
    typography: "{typography.body-md}"
    rounded: "{rounded.sm}"
    padding: 10px
  button-primary-hover:
    backgroundColor: "{colors.secondary}"
    textColor: "{colors.paper}"
    rounded: "{rounded.sm}"
    padding: 10px
  button-quiet:
    backgroundColor: "{colors.quill-soft}"
    textColor: "{colors.bark}"
    typography: "{typography.body-md}"
    rounded: "{rounded.sm}"
    padding: 10px
  button-danger:
    backgroundColor: "{colors.clay}"
    textColor: "{colors.paper}"
    typography: "{typography.body-md}"
    rounded: "{rounded.sm}"
    padding: 10px
  card:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: 16px
  status-authentic:
    backgroundColor: "{colors.leaf-soft}"
    textColor: "{colors.leaf-dark}"
    typography: "{typography.label}"
    rounded: "{rounded.sm}"
    padding: 4px
  status-pending:
    backgroundColor: "{colors.quill-soft}"
    textColor: "#8A5A10"
    typography: "{typography.label}"
    rounded: "{rounded.sm}"
    padding: 4px
  status-tampered:
    backgroundColor: "{colors.clay-soft}"
    textColor: "{colors.clay-dark}"
    typography: "{typography.label}"
    rounded: "{rounded.sm}"
    padding: 4px
  input:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    padding: 10px
  table-header:
    backgroundColor: "{colors.neutral}"
    textColor: "{colors.faded}"
    typography: "{typography.label}"
    padding: 8px
  card-lined:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: 16px
---

# Cinnamon Harvest Admin

The oversight console for **Cinnamon Trace** — Sri Lanka's blockchain-verified
cinnamon supply-chain platform. This is the Department of Cinnamon
Development's window into the ledger: users, batches, and tamper-evidence at
a glance.

The palette is inherited verbatim from the farmer-facing mobile app
(`app/lib/app/theme.dart`, the "Cinnamon Harvest" system). The mobile app is
warm, organic and touch-first; the admin console keeps the warmth but trades
touch-first sizing for **data density, scan-ability and print-friendliness** —
government staff read tables all day.

## Colors

- **Primary (`#8B4A2B`, "cinnamon"):** warm cinnamon bark — primary actions,
  active nav, focus rings. The brand anchor.
- **Secondary (`#4A2C17`, "bark"):** deep bark — headings, sidebar surface,
  hover states.
- **Tertiary / quill (`#D98E32`):** quill-gold amber — accents and the
  PENDING verdict.
- **Neutrals:** cream `#FAF3E7` page background, paper `#FFFDF8` cards, ink
  `#2B1D12` text, faded `#7A6A58` secondary text, line `#E8DCC8` hairlines.
- **Verdict colors** (the semantic heart of this console):
  - **AUTHENTIC → leaf `#4C7A34` on leaf-soft `#E7EFDD`** — chain intact,
    Bitcoin witness confirms.
  - **PENDING → dark amber `#8A5A10` on quill-soft `#F7E8D2`** — chain
    intact, awaiting nightly anchor. (Darkened from raw quill for AA
    contrast on the soft tint.)
  - **TAMPERED → clay `#B4452F` on clay-soft `#F6E0DA`** — hash chain
    disagrees; the red-alert state of the whole system.

## Typography

**Baloo 2** for display (headings, big metric numbers) — the app's friendly
rounded display face, signalling "same product, different desk". **Noto
Sans** for body and data — dense, unambiguous, tabular-friendly. `label`
tokens are uppercase-tracked 600-weight micro-labels for table headers and
KPI captions.

## Layout

Cream page, paper cards on an 8/16/24 grid. Left sidebar in bark for global
nav; content in cards with 12px radii. Tables rule the console: zebra-free,
hairline-separated, sticky headers, right-aligned numerics. Radius tokens
(8/12/18) come straight from the app's `radiusSm`/`radius` metrics.

## Components

`status-*` badges are the load-bearing components — every batch view filters
and colour-codes by them. `button-primary` (cinnamon) is the only
high-emphasis action; destructive user-management actions use
`button-danger` (clay) and always pass through a confirm dialog. Tables use
`table-header` styling with `label` typography.

## Do's and Don'ts

- **Do** colour verdicts exactly as tokened — green/yellow/red are
  compliance signals, not decoration; never tint anything else with them.
- **Do** keep every filtered view exportable — CSV accompanies every table.
- **Don't** alter batch or event data from this console — it is a window
  onto an immutable ledger; user administration is the only write path.
- **Don't** use pure quill `#D98E32` as text on soft tints — use the
  darkened `#8A5A10` for AA contrast.

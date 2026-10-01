# Design — Catlab Bro

A locked design system for the two pages a person sees: the admin page
(`pocketbase/pb_public/index.html`, the Home Assistant sidebar panel at `/_setup/`) and the
example app (`ui/index.html`). Every redesign reads this file first; extend or amend it here,
never per page. Repos made from the template inherit it.

## World

**Release notes.** The admin page reads like the project's own changelog: what is running (a
version and the commit it was built from), what is unreleased (drop-in migrations that exist only
on this device), and what the app needs (its card, its UI). The example app is a typeset index of
the user's records. Paper discipline on a dark ground: hairlines, measure, type; no cards, no
gradients, no glow.

## Genre
editorial (Hallmark) · visitor mode Operate (Impeccable)

## Macrostructure family
- Admin page: **02 Long Document**, written as release notes. Section heads sit inline in a single
  measure. Navigational links are typographic; the few decisive actions (Apply migrations, Update
  UI) stay real buttons because this is an operator page.
- App pages: **13 Index-First**. The records are the page; one short line introduces them.
- Nav: **N9 edge-aligned** (name hard left, one action hard right). Footer: **Ft4 dense colophon**.

## Theme (custom · tuned)
Physical scene: the owner, at home, in the evening, opens the panel inside Home Assistant's dark
theme on a laptop or a phone. The ground is Home Assistant's own neutral dark (#121212 content,
#1a1a1a bars) at chroma 0, so the page sits flush in the panel; the warmth lives in the ink. Never
a blue-black slate, never pure black or white. (A deliberate deviation from Hallmark's tint-every-
neutral gate: the host's ground wins.)

| token | value | role |
|---|---|---|
| `--color-paper` | `oklch(18.2% 0 0)` | ground (#121212) |
| `--color-paper-2` | `oklch(21.6% 0 0)` | quiet band: the update bar, inputs, skeletons (#1a1a1a) |
| `--color-ink` | `oklch(92% 0.014 85)` | text |
| `--color-ink-2` | `oklch(74% 0.012 85)` | secondary text |
| `--color-ink-3` | `oklch(62% 0.012 85)` | meta, colophon, state words at rest |
| `--color-rule` | `oklch(31% 0 0)` | rules: 1px between entries, 2px between sections |
| `--color-control` | `oklch(55% 0 0)` | control borders, link underlines, dotted leaders (3:1 on both grounds) |
| `--color-accent` | `oklch(76% 0.13 155)` | the only colour that means *press* (buttons, links that act) |
| `--color-accent-hover` | `oklch(81% 0.12 155)` | the accent under the pointer |
| `--color-accent-ink` | `oklch(22% 0.03 155)` | text on the accent |
| `--color-unreleased` | `oklch(82% 0.13 80)` | unreleased / at risk / pending / a newer build |
| `--color-danger` | `oklch(72% 0.15 28)` | failure text only |
| `--color-focus` | `oklch(86% 0.11 155)` | focus ring |
| `--color-selection` | `oklch(36% 0.02 85)` | text selection (not green: green means press) |
| `--color-qr-plate` / `--color-qr-ink` | `oklch(96% 0.008 85)` / the paper | the QR code: dark modules on a light plate, as scanners expect |

Colour strategy: restrained. One action colour, one state colour (amber), everything else ink on
ground. One ink, one meaning: green is never a state (a ticked note is ink, a "Copied" is ink),
amber is never an action.

## Typography
One family for both scripts the owner writes in, self-hosted (Impeccable: an installed face is not
a fallback for the design): **IBM Plex Sans Thai** 400 and 700, Latin and Thai in one family, as in
Nonsense Matters; **IBM Plex Mono** 400 (Latin-1) for data. IBM's own files, unmodified (only the
file names), OFL, in `vendor/fonts/` (admin page) and `fonts/` (app) with `OFL.txt`: 40 KB per
sans weight, 18 KB mono. The two sans weights are preloaded; `font-display: swap`.
- `--font-display` / `--font-body`: `"IBM Plex Sans Thai", system-ui, -apple-system, "Segoe UI",
  "Noto Sans Thai", sans-serif`. Headings 700 with -0.01em tracking, prose 400. Roman only: no
  italic headings anywhere.
- `--font-mono`: `"IBM Plex Mono", ui-monospace, "SF Mono", "Cascadia Mono", Menlo, Consolas,
  monospace`, only for versions, hashes, paths, links, logins, dates; tabular numerals.
- Thai stacks marks above and below the line: headings 1.3, one-line controls and state words
  1.3, prose 1.6. Never set Thai at line-height 1.
- Scale (rem): 0.75 · 0.875 · 1 · 1.125 · 1.375 · 1.75 (`--text-xs` … `--text-2xl`). Prose measure
  62ch. Headings `text-wrap: balance`, prose `pretty`.

## Spacing
4-point named scale: `--space-3xs` .25rem · `2xs` .5 · `xs` .75 · `sm` 1 · `md` 1.5 · `lg` 2 ·
`xl` 3 · `2xl` 4.5. Page gutter `--space-sm`, `--space-lg` from 48rem. Controls are 2.75rem (44 px)
tall, inputs and buttons alike; radius 2px. More space above a section head than below it. Pages
use tokens, never raw values.

## Motion
Nothing moves. Hover and press change colour over 150 ms (`--ease-out: cubic-bezier(0.16, 1, 0.3,
1)`); a pressed button sinks 1px; focus rings and every state change are instant.
`prefers-reduced-motion` drops the colour transitions and the press offset.

## Microinteractions
- Silent success: a status line in place, never a toast. A button's success state ("Copied",
  "Saved") is ink on its outline for 1.5 s, then its label returns.
- Reversible actions need no confirmation; a costly one states its consequence beside the button
  ("Apply 1 migration" — *restarts the add-on*; "Update to ui-v0.1.2" — *no restart*).
- Every button: default, hover, `:focus-visible` (2px ring, instant), active, disabled, loading,
  error, success.
- A message slot that sits between controls reserves its line; one that ends a form collapses
  while empty.

## Controls
- Height 2.75rem (44 px) for buttons and inputs alike; radius 2px; labels 700, never wrap.
- **Primary** (the one action that resolves the section's state: Apply, Update, Add, Sign in):
  accent fill, accent-ink text, padding 0 × 1rem.
- **Secondary** (Upload, Commit to repo, Copy link, Save, Load again): transparent, 1px
  `--color-control` border, ink text.
- **Quiet** (utilities: Download, Copy path, Sign out): ink-2 text with a control-colour
  underline, no padding, so it aligns with the text around it when a row wraps.
- Links: **accent** only for the off-page action that resolves a state ("Install it on the add-on
  page"); **bold ink** for navigation (Open dashboard, Open the app); plain ink with a control
  underline in prose. Link text never wraps. The new-tab icon sits against its link.
- States are words, 700, uppercase, 0.06em tracking: RUNNING · AVAILABLE · PENDING · APPLIED ·
  NOT IN THE REPO · IN THE REPO · UP TO DATE · PINNED. Amber for what needs attention (PENDING,
  NOT IN THE REPO, AVAILABLE), ink-3 for the rest.
- Paths break only after a `/` (`<wbr>`), never inside a name. Dates: a drop-in's date comes from
  its `<unix time>_` prefix; notes show their created date; both in mono, in the device's locale.

## Icons
One authored SVG, stroke 1.5 on a 16 grid: the "leaves this page" arrow (new tab, GitHub links).
No glyphs or emoji stand in for icons; states are words.

## What both pages MUST share
Tokens, the two type stacks, the button and link voice, the state words, the hairline language.
The token block (`/* tokens:start */` … `/* tokens:end */`) is repeated in both pages because they
deploy separately (pb_public in the image, ui/ as a release's dist.zip) and there is no build step;
`scripts/local-e2e.sh` fails when the two blocks differ.

## What pages MAY differ on
Macrostructure within the family above.

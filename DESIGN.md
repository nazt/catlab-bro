---
name: Catlab Bro
description: "The backend's own release notes, set flush in Home Assistant's dark panel: warm Plex ink on a neutral ground, green to press, amber for what needs attention."
colors:
  paper: "oklch(18.2% 0 0)"
  paper-2: "oklch(21.6% 0 0)"
  ink: "oklch(92% 0.014 85)"
  ink-2: "oklch(74% 0.012 85)"
  ink-3: "oklch(62% 0.012 85)"
  rule: "oklch(31% 0 0)"
  control: "oklch(55% 0 0)"
  accent: "oklch(76% 0.13 155)"
  accent-hover: "oklch(81% 0.12 155)"
  accent-ink: "oklch(22% 0.03 155)"
  unreleased: "oklch(82% 0.13 80)"
  danger: "oklch(72% 0.15 28)"
  focus: "oklch(86% 0.11 155)"
  selection: "oklch(36% 0.02 85)"
  qr-plate: "oklch(96% 0.008 85)"
  qr-ink: "oklch(18.2% 0 0)"
typography:
  display:
    fontFamily: '"IBM Plex Sans Thai", system-ui, -apple-system, "Segoe UI", "Noto Sans Thai", sans-serif'
    fontSize: "1.75rem"
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: "-0.01em"
  headline:
    fontFamily: '"IBM Plex Sans Thai", system-ui, -apple-system, "Segoe UI", "Noto Sans Thai", sans-serif'
    fontSize: "1.375rem"
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: "normal"
  title:
    fontFamily: '"IBM Plex Sans Thai", system-ui, -apple-system, "Segoe UI", "Noto Sans Thai", sans-serif'
    fontSize: "1.125rem"
    fontWeight: 700
    lineHeight: 1.4
  body:
    fontFamily: '"IBM Plex Sans Thai", system-ui, -apple-system, "Segoe UI", "Noto Sans Thai", sans-serif'
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.6
  body-sm:
    fontFamily: '"IBM Plex Sans Thai", system-ui, -apple-system, "Segoe UI", "Noto Sans Thai", sans-serif'
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: '"IBM Plex Sans Thai", system-ui, -apple-system, "Segoe UI", "Noto Sans Thai", sans-serif'
    fontSize: "0.875rem"
    fontWeight: 700
    lineHeight: 1.3
  state:
    fontFamily: '"IBM Plex Sans Thai", system-ui, -apple-system, "Segoe UI", "Noto Sans Thai", sans-serif'
    fontSize: "0.75rem"
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: "0.06em"
  colophon:
    fontFamily: '"IBM Plex Sans Thai", system-ui, -apple-system, "Segoe UI", "Noto Sans Thai", sans-serif'
    fontSize: "0.75rem"
    fontWeight: 400
    lineHeight: 1.7
  mono:
    fontFamily: '"IBM Plex Mono", "IBM Plex Sans Thai", ui-monospace, "SF Mono", "Cascadia Mono", Menlo, Consolas, monospace'
    fontSize: "0.875em"
    fontWeight: 400
    fontFeature: '"tnum"'
rounded:
  radius: "2px"
spacing:
  3xs: "0.25rem"
  2xs: "0.5rem"
  xs: "0.75rem"
  sm: "1rem"
  md: "1.5rem"
  lg: "2rem"
  xl: "3rem"
  2xl: "4.5rem"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.radius}"
    padding: "0 1rem"
    height: "2.75rem"
  button-primary-hover:
    backgroundColor: "{colors.accent-hover}"
  button-secondary:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.radius}"
    padding: "0 1rem"
    height: "2.75rem"
  button-secondary-hover:
    backgroundColor: "{colors.paper-2}"
  button-quiet:
    backgroundColor: "transparent"
    textColor: "{colors.ink-2}"
    typography: "{typography.label}"
    padding: "0"
    height: "2.75rem"
  button-quiet-hover:
    textColor: "{colors.ink}"
  button-error:
    backgroundColor: "transparent"
    textColor: "{colors.danger}"
  button-success:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
  link-act:
    textColor: "{colors.accent}"
  link-act-hover:
    textColor: "{colors.accent-hover}"
  link-nav:
    textColor: "{colors.ink}"
    padding: "0 0.5rem"
    height: "2.75rem"
  input:
    backgroundColor: "{colors.paper-2}"
    textColor: "{colors.ink}"
    rounded: "{rounded.radius}"
    padding: "0 0.75rem"
    height: "2.75rem"
  masthead:
    textColor: "{colors.ink}"
    typography: "{typography.title}"
    height: "3.5rem"
  state-word:
    textColor: "{colors.ink-3}"
    typography: "{typography.state}"
  state-word-attention:
    textColor: "{colors.unreleased}"
  entry-row:
    textColor: "{colors.ink}"
    padding: "0.75rem 0"
  index-row:
    textColor: "{colors.ink}"
    padding: "0.5rem 0"
    height: "2.75rem"
  update-bar:
    backgroundColor: "{colors.paper-2}"
    textColor: "{colors.ink}"
    typography: "{typography.body-sm}"
  qr-plate:
    backgroundColor: "{colors.qr-plate}"
    rounded: "{rounded.radius}"
    padding: "0.5rem"
    size: "11rem"
  colophon:
    textColor: "{colors.ink-3}"
    typography: "{typography.colophon}"
---

# Design System: Catlab Bro

The locked system for the two pages a person sees: the admin page (`pocketbase/pb_public/index.html`, the Home Assistant sidebar panel at `/_setup/`) and the example app (`ui/index.html`). Every redesign reads this file first; extend or amend it here, never per page. Repos made from the template inherit it. The frontmatter mirrors the pages' shared token block value for value, so change both together; `.impeccable/design.json` carries what the frontmatter cannot hold (tonal ramps, motion, breakpoints, component snippets).

## Overview

**Creative North Star: "The Release Notes"**

The admin page reads like the backend's own changelog: what is running (a version and the commit it was built from), what is unreleased (drop-in migrations that exist only on this device), and what the app needs (its login, its UI). The example app is a typeset index of the user's records on the same paper. Paper discipline on a dark ground: hairlines, measure, type; no cards, no gradients, no glow. It refuses the centred card of buttons and the stack of cards for form, list and buttons.

The physical scene: the owner, at home in the evening, opens the panel inside Home Assistant's dark theme on a laptop or a phone. The ground is Home Assistant's own neutral dark at chroma 0, so the page sits flush in the panel; the warmth lives in the ink. The density is a document's, not a dashboard's: one left-hung column, each section's state first, then the one action that resolves it, with its consequence written beside it.

Nothing moves. Hover and press change colour over 150ms on one ease-out curve; a pressed button sinks 1px; focus rings and every state change are instant, and reduced motion drops even the colour fades.

**Key Characteristics:**
- Home Assistant's neutral ground (#121212, bars #1a1a1a) under a warm off-white ink in three steps.
- Green only to press, amber only for what needs attention, red only for what failed.
- One family for Thai and Latin (IBM Plex Sans Thai 400/700); IBM Plex Mono only for machine strings.
- Rules, not boxes: 1px between entries, 2px between sections, dotted leaders in the index.
- Flat everywhere; 2px corners; 44px controls.
- States are words; the only icon is the new-tab arrow.
- Silent success; a costly action states its consequence.

## Colors

Restrained: one hue to press, one for attention, one for failure; everything else is warm ink on the host's neutral ground.

### Primary
- **Press Green** (`accent`, oklch(76% 0.13 155)): the only colour that means press: the fill of primary buttons, the link that performs an off-page action ("Install it on the add-on page"), and the text caret.
- **Press Green, Lit** (`accent-hover`, oklch(81% 0.12 155)): the accent under the pointer, on fills and on act links.
- **Deep Green Ink** (`accent-ink`, oklch(22% 0.03 155)): the label on a green fill.
- **Focus Green** (`focus`, oklch(86% 0.11 155)): the 2px focus ring on every button, link, input and checkbox; it appears instantly.

### Secondary
- **Unreleased Amber** (`unreleased`, oklch(82% 0.13 80)): what needs attention: the state words PENDING, NOT IN THE REPO and AVAILABLE, and a status line while something is pending ("Restarting to apply the migration…"). Text only.

### Tertiary
- **Failure Red** (`danger`, oklch(72% 0.15 28)): failure only: an error status line, the outline and label of a button whose action failed ("Try again"), the border of an invalid field, the sign-in error. Never a fill, never a warning (warnings are amber).

### Neutral
- **Panel Paper** (`paper`, oklch(18.2% 0 0), Home Assistant's #121212): the ground of both pages; also the dark modules of the QR code (`qr-ink`) and the paper behind an index title that hides its dotted leader.
- **Bar Paper** (`paper-2`, oklch(21.6% 0 0), Home Assistant's #1a1a1a): the one tonal step: the app's update bar, input wells, skeleton bars, a secondary button under the pointer.
- **Warm Ink** (`ink`, oklch(92% 0.014 85)): headings, ledes, notices, status lines, code, link text and input values.
- **Second Ink** (`ink-2`, oklch(74% 0.012 85)): supporting paragraphs (the note count, the sign-in line), quiet buttons, the new-tab icon at rest, colophon links and code.
- **Meta Ink** (`ink-3`, oklch(62% 0.012 85)): bylines, asides, consequences, help lines, fact terms, dates, entry notes, the colophon, empty states, placeholders, state words at rest, and a note that is done, checkbox included.
- **Hairline** (`rule`, oklch(31% 0 0)): every rule: 1px under the masthead and the update bar, between entries and over the colophon; 2px between admin sections; the scrollbar thumb.
- **Control Grey** (`control`, oklch(55% 0 0)): 1px control borders, link underlines and dotted leaders; at least 3:1 on both grounds.
- **Selection Umber** (`selection`, oklch(36% 0.02 85)): text selection under ink. Not green: green means press.
- **QR Plate** (`qr-plate`, oklch(96% 0.008 85)): the light plate under the setup QR code, the one light surface in the system, because scanners expect dark modules on light.

### Named Rules
**The One Ink, One Meaning Rule.** Green means press, amber means needs attention, red means failed, and none stands in for another. A ticked note is meta ink, "Copied" and "Saved" are ink, a selection is umber; amber never fills a button or colours a link.

**The Host's Ground Rule.** The ground is Home Assistant's own neutral dark at chroma 0 (#121212 content, #1a1a1a bars), so the page sits flush in its panel; the warmth lives in the ink (hue 85). This deliberately overrides Hallmark's tint-every-neutral gate, and the owner signed off on it. Never a blue-black slate, never pure black, never pure white.

## Typography

**Display Font:** IBM Plex Sans Thai 700 (with system-ui, -apple-system, Segoe UI, Noto Sans Thai, sans-serif)
**Body Font:** IBM Plex Sans Thai 400 (same stack)
**Label/Mono Font:** IBM Plex Mono 400, Latin-1 subset (Thai inside a mono run falls through to IBM Plex Sans Thai, then ui-monospace, SF Mono, Cascadia Mono, Menlo, Consolas)

**Character:** One family for both scripts the owner writes in, Thai and Latin in one voice, as in Nonsense Matters; Plex Mono marks what a machine wrote. Self-hosted, so the design never rests on a system fallback: IBM's own files, unmodified but for their names, OFL, in `vendor/fonts/` (admin page) and `fonts/` (app) beside `OFL.txt`, about 40 KB per sans weight and 18 KB for the mono. The two sans weights are preloaded; `font-display: swap`.

### Hierarchy
- **Display** (700, 1.75rem, 1.3, -0.01em): the page's one h1: "Running 0.1.8", "Notes", "Sign in". A version inside it takes lining, tabular figures. Balanced wrapping.
- **Headline** (700, 1.375rem, 1.3, untracked): the admin page's section heads: Unreleased, Set up an app, App UI.
- **Title** (700, 1.125rem, 1.4): the project's name, hard left in the masthead; it truncates with an ellipsis rather than wrap.
- **Body** (400, 1rem, 1.6, 62ch measure): prose, ledes, notices and status lines; the app's input values. Pretty wrapping.
- **Body small** (400, 0.875rem, 1.6): bylines, asides, consequences, help lines, fact terms, entry notes, the update bar.
- **Label** (700, 0.875rem, 1.3): button labels, which never wrap; field labels take the same size and weight at prose leading.
- **State** (700, 0.75rem, 1.3, 0.06em, uppercase): the state words.
- **Colophon** (400, 0.75rem, 1.7): the footer line.
- **Mono** (400, 0.875em of its context, tabular figures): versions, hashes, paths, URLs, logins, the setup link, dates. A date sits one step below what it annotates: 0.75rem beside a drop-in's file name, 0.875rem beside a note's title.

### Named Rules
**The One Family, Two Scripts Rule.** IBM Plex Sans Thai sets Thai and Latin alike, at 400 and 700 only, roman only. No second sans, no italic, no other weight.

**The Machine Strings Rule.** Mono is for what a machine wrote or will read: versions, hashes, paths, URLs, logins, dates, and a field whose value is a release tag or a URL. Never for prose, labels or headings.

**The Thai Leading Rule.** Thai stacks marks above and below the line: 1.3 for headings, one-line controls and state words, 1.6 for prose. Never line-height 1.

## Layout

One column per page, hung from the same gutter as the masthead name and never centred: the admin page's document is at most 46rem wide, the app's index 40rem, and a wide window leaves the right side as empty paper. The page gutter is 1rem, 2rem from 48rem. Prose holds a 62ch measure.

Spacing is a 4-point named scale, `3xs` (0.25rem) to `2xl` (4.5rem). The rhythm as built:
- **Page:** 2rem above the first heading, 4.5rem below the last section.
- **Sections (admin):** 3rem, a 2px rule, then 2rem before the next head; 0.5rem from a head to its first line.
- **Inside a section:** 0.75rem between paragraphs; 1rem above an actions row or an entry list; 1.5rem above a form or the setup block. Actions wrap with 0.5rem between rows and 1rem between controls.
- **Rows:** a release entry has 0.75rem above and below; an index row is at least 2.75rem with 0.5rem padding.
- **Masthead:** at least 3.5rem, 0.5rem vertical padding, the gutter at the sides. **Colophon:** 1rem above, 1.5rem below, items 1.5rem apart and wrapping.

Responsive behaviour: below 30rem an admin entry's state words drop under its name and the setup facts stack, term over value; from 40rem the setup QR stands left of its facts; from 48rem the gutter doubles. Both pages work at 320px: the name truncates, paths break only after a `/`, labels and links never wrap, action rows wrap.

### Named Rules
**The Left-Hung Column Rule.** The reading column starts at the gutter under the masthead name and never centres. Its width is the only thing a page tunes (46rem admin, 40rem app).

**The More-Above Rule.** A section head has more space above it than below: 3rem, a 2px rule and 2rem above; 0.5rem below.

## Elevation & Depth

Flat. Neither page has a box-shadow, text-shadow, gradient, blur or glow, at rest or in any state. Depth is one tonal step from `paper` to `paper-2` (the app's update bar, input wells, skeleton bars, a secondary button under the pointer), and structure is drawn with rules: 1px hairlines between entries, 2px between sections. The only spatial cue is a pressed button sinking 1px. Focus is a 2px outline, never a shadow.

### Named Rules
**The Paper Rule.** Surfaces are flat in every state. Depth is one tonal step and a rule; a press is a 1px sink; nothing casts a shadow or glows.

## Shapes

Squared with the edge just taken off: every box that has a corner rounds it at 2px (`radius`): buttons, inputs, the QR plate, skeleton bars, and the focus ring around links. Lines carry the rest of the form: 1px hairline rules, 2px section rules, a 1px dotted leader from an index title to its date, 1px solid borders on secondary buttons and inputs, and 1px underlines offset 3px on links and quiet buttons. The one icon is drawn at stroke 1.5 on a 16 grid with round caps and joins, sized 1em. The setup QR is a square 11rem plate with 0.5rem of light margin.

### Named Rules
**The Two-Pixel Rule.** Every corner in the system is 2px. A pill, a circle or a large radius would be a second shape language.

## Components

### Buttons
Typeset, not decorated: a 700 label in a 44px box with a 2px corner.
- **Shape:** 2.75rem (44px) tall at minimum, 2px corners; labels never wrap.
- **Primary:** green fill, deep green label, 1rem side padding. Only for the one action that resolves a section's state: Apply 1 migration, Update to ui-v0.1.2, Restart now, Sign in, Add.
- **Secondary:** transparent, 1px control-grey border, ink label: Upload a migration, Commit to repo, Copy link, Save, Check again, Load again. Under the pointer it takes the bar paper and a meta-ink border.
- **Quiet:** ink-2 text with a control-grey underline and no side padding, so it lines up with the text around it when a row wraps; it keeps the 44px height. For utilities: Download, Copy path, Sign out. Under the pointer it turns ink and its underline follows.
- **Hover / Focus / Press:** colour changes over 150ms on `cubic-bezier(0.16, 1, 0.3, 1)`; `:focus-visible` shows a 2px focus-green ring 2px out, instantly; a press sinks the button 1px. Reduced motion removes the fades and the sink.
- **Disabled / Loading / Error / Success:** disabled at 0.55 opacity with a not-allowed cursor; loading at 0.8 with a progress cursor and a label that says what is happening ("Restarting…", "Saving…", "Signing in…"); error turns the button into a red outline with a red label ("Try again"); success turns it into an ink label on a control-grey outline ("Copied", "Saved") for 1.5s, then its own label returns.

### Links
- **Act:** green text with a green underline, only for an off-page action that resolves a state ("Install it on the add-on page"); lit green under the pointer.
- **Navigation:** 700 ink with a control-grey underline in a 44px-tall hit area (Open dashboard, Open the app).
- **In prose:** plain ink with a 1px control-grey underline offset 3px; the underline takes the text colour under the pointer, and a pressed link dims to ink-2. Colophon links are ink-2.
- Link text never wraps. The new-tab arrow sits against its link: inside it (the commit hash, Commit to repo) or as its own 28 × 44px target beside it (Open dashboard, inside Home Assistant).

### Inputs / Fields
- **Style:** a bar-paper well with a 1px control-grey border, 2px corners, 2.75rem tall, 0.75rem side padding; ink value at 1rem, meta-ink placeholder, green caret. A field whose value is a release tag or a URL sets it in mono.
- **Label and help:** a 700 0.875rem label above; a 0.875rem meta-ink help line below that reserves its line, so a message never moves the form.
- **Hover / Focus:** the border lightens to meta ink under the pointer; `:focus-visible` adds a 2px focus-green ring 1px out.
- **Error / Disabled:** an invalid field takes a red border and its help line turns red and says the fix ("Use latest, a release tag such as ui-v0.1.0, a dist.zip URL, or bundled."); typing clears both. Disabled at 0.55 opacity.

### Navigation
- **Masthead (N9):** the project's name hard left (700, 1.125rem, ellipsis), one action hard right (the admin page's Open dashboard, with its new-tab arrow inside Home Assistant; the app's quiet Sign out), a hairline below; at least 3.5rem tall.
- **Colophon (Ft4):** a hairline above, then one dense wrapping line of 0.75rem meta ink. Admin: PocketBase version, add-on version and commit, repository, who is signed in. App: Setup, UI version, who is signed in. Items never break inside.

### State Words
States are words: 700, 0.75rem, uppercase, 0.06em tracking, never wrapping. Amber for what needs attention (PENDING, NOT IN THE REPO, AVAILABLE, RESTART NEEDED); meta ink for the rest (APPLIED, IN THE REPO, UP TO DATE, PINNED). A group sets them 0.5rem apart, 0.25rem between lines. They lead a notice line or close an entry row.

### Release Entries (admin)
The admin page's ledger: a list ruled in hairlines, top and between. Each entry is the drop-in's file name in mono with its date (read from the `<unix time>_` prefix) in 0.75rem mono meta ink, its state words at the right, then a full-width meta note or a row of actions (Commit to repo as a secondary button carrying the new-tab arrow, Download as a quiet button). Paths break only after a `/`.

### The Index (app)
The app's records as a typeset index: rows ruled in hairlines, each a checkbox, the title, and a dotted control-grey leader running to a 0.875rem mono date on the title's last line. The title's own paper hides the leader behind the words. Under the pointer the title underlines; a done note goes meta ink with a line-through, and its checkbox is meta ink, never green. While loading, three bar-paper skeleton bars (0.75rem tall, 2px corners) hold the rows.

### Update Bar and Notices
- **Update bar (app):** a full-width bar-paper band under the masthead with a hairline below and 0.875rem ink text: an amber AVAILABLE, the new version in mono, and who installs it, with a plain link to Setup (installing is an admin's job).
- **Notice (admin):** the same news inline in the running section: an amber AVAILABLE, the version in mono, then the green act link that resolves it.

### Setup QR and Facts (admin)
The setup link as a QR code: dark modules on the light QR plate, 11rem square, 0.5rem margin, 2px corners. From 40rem it stands left of a two-column list of facts: terms in 0.875rem meta ink, values in mono.

### Icon
One authored SVG: the "leaves this page" arrow, stroke 1.5 on a 16 grid, round caps and joins, 1em, in the current text colour. It marks new-tab and GitHub links on the admin page. No glyph or emoji stands in for an icon.

### Status Lines
A status line reports in place: ink, amber while something is pending, red on failure, collapsed while empty. Help lines under a field reserve their line instead.

### Named Rules
**The Consequence Rule.** A costly action states its consequence beside its button in 0.875rem meta ink ("restarts the add-on", "no restart", "to serve the new source"). A reversible action needs no confirmation.

**The Silent Success Rule.** Success is a status line in place, or the button itself turning ink on its outline for 1.5s. Never a toast.

**The State Word Rule.** A state is a word, never a badge, dot, glyph or colour chip.

## Do's and Don'ts

### Do:
- **Do** keep the token block between `/* tokens:start */` and `/* tokens:end */` identical, line for line, in both pages, and mirror any change in this file's frontmatter; `scripts/local-e2e.sh` fails when the two blocks differ.
- **Do** lay the ground in `paper` (#121212) and bands in `paper-2` (#1a1a1a) at chroma 0, and keep the warmth in the ink (hue 85).
- **Do** give every button all eight states: default, hover, focus-visible (2px ring, 2px out, instant), active (1px sink), disabled (0.55), loading (0.8, a label that says what is happening), error (red outline), success (ink outline for 1.5s).
- **Do** write a costly action's consequence beside its button, in 0.875rem meta ink.
- **Do** keep buttons and inputs 2.75rem (44px) tall with 2px corners.
- **Do** set versions, hashes, paths, URLs, logins and dates in IBM Plex Mono, and break a path only after a `/`.
- **Do** separate entries with a 1px hairline and sections with a 2px rule, with more space above a section head than below it.
- **Do** take colour, the type scale, spacing, radius and motion from tokens (code's 0.875em is the one relative size); keep raw values to component dimensions (column widths, the 11rem QR, the 3.5rem masthead) and optical offsets (the 3px underline, the 2px focus offset).

### Don't:
- **Don't** use green for a state: a done note's checkbox is meta ink, "Copied" and "Saved" are ink, a text selection is umber.
- **Don't** use amber for an action: it never fills a button or colours a link.
- **Don't** tint the ground or swap it for a blue-black slate, pure black, or pure-white text.
- **Don't** add cards, shadows, glows or gradients; structure is rules and type.
- **Don't** confirm a success with a toast.
- **Don't** set italic or any weight but 400 and 700: only those faces ship, so anything else is synthesized.
- **Don't** set Thai at line-height 1.
- **Don't** let a glyph or emoji stand in for an icon or a state; states are words.
- **Don't** let a button label, link text or state word wrap, or a path break inside a name.
- **Don't** set an input's text below 1rem (16px): phones zoom the page when such a field takes focus.

## Macrostructure family
- **Genre:** editorial (Hallmark) · visitor mode Operate (Impeccable) · theme custom (tuned), with one recorded deviation: gate 22, neutrals at chroma 0 (The Host's Ground Rule).
- **Admin page:** 02 Long Document, written as release notes. Section heads sit inline in a single measure. Navigational links are typographic; the few decisive actions (Apply migrations, Update) stay real buttons because this is an operator page.
- **App pages:** 13 Index-First. The records are the page; one short line introduces them.
- **Nav:** N9 edge-aligned (name hard left, one action hard right). **Footer:** Ft4 dense colophon.

## What both pages MUST share
Tokens, the two type stacks, the button and link voice, the state words, the hairline language. The token block (`/* tokens:start */` … `/* tokens:end */`) is repeated in both pages because they deploy separately (pb_public in the image, ui/ as a release's dist.zip) and there is no build step; `scripts/local-e2e.sh` fails when the two blocks differ. The add-on's copy of the admin page under `addon/<slug>/rootfs/opt/app/pb_public/` is written by `scripts/sync-addon.sh`; edit `pocketbase/pb_public/` only.

## What pages MAY differ on
Macrostructure within the family above; the column's width (46rem admin, 40rem app); the masthead's one action; how much of a date shows (the admin page adds the year); and whether a newer build is announced as a band (app) or inline (admin).

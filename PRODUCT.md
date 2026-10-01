# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users
The Home Assistant owner who runs one or more PocketBase backends made from this template. They
open the add-on's sidebar panel, already signed in to Home Assistant, to operate the backend:
check that it is up and which version and commit it runs, hand an app its login (setup link / QR),
open the PocketBase dashboard, apply a drop-in migration and commit it back to the repository,
and update the app's UI. Secondary: a developer who just created a repo from the template sees the
same pages on first run.

## Product Purpose
A new PocketBase backend per repository in one click. The official PocketBase binary, pinned and
SHA-256 verified, runs standalone (docker compose) or as a Home Assistant add-on from the same
image, with logins provisioned on first start. Success: the owner never edits a container, never
types a second password, and never loses a migration.

## Positioning
One backend per repo, Home Assistant-native, with the repository as the source of truth: the
sidebar panel signs the Home Assistant user in to PocketBase, drop-in migrations are committed
back under the same name, every backend push releases a new add-on version by itself, and the
app's UI updates from a GitHub release without a restart.

## Operating Context
- Inside Home Assistant's sidebar panel (an ingress iframe, usually a dark Home Assistant theme),
  on desktop and on a phone. The admin page lives at `/_setup/` when the app's own UI owns `/`.
- The PocketBase dashboard (`/_/`) opens inside the panel or in its own tab.
- GitHub is where changes are committed (the panel's "Commit to repo" opens GitHub's editor with
  the user's own login) and where UI releases (`ui-v*` with `dist.zip`) come from.
- Home Assistant's add-on page is where versions are installed (the add-on does not update itself).

## Capabilities and Constraints
- Plain static HTML/CSS/JS, no build step; every URL relative (the pages run under the ingress
  prefix and at the published port).
- Admin page (`pocketbase/pb_public/index.html`): auto-login status, running version + commit,
  dashboard, app setup link + QR (contains the app password: only shown in the signed-in panel),
  app UI status / update / source, drop-in migrations (upload, pending, apply = restart,
  commit to repo, in the repo now).
- Example app (`ui/index.html`): signs in with the app login, lists / adds / toggles notes; it is
  meant to be replaced by the project's real app.
- Superuser-only APIs under `/api/app/*`; auto-login is trusted only from Supervisor's ingress
  proxy and the first panel user claims the add-on.
- Vendored: qrcode-generator 1.4.4 (MIT), IBM Plex Sans Thai and IBM Plex Mono (OFL). No other
  runtime dependencies.

## Brand Commitments
Name: "PocketBase Template" (each repo renames itself, e.g. "Catlab Bro"). MIT licensed,
Soul Brews Studio. No logo or palette is committed.

## Evidence on Hand
- Live run recorded in `docs/home-assistant/` (catlab-bro 0.1.0 → 0.1.8, ui-v0.1.0 → ui-v0.1.1).
- No users, metrics, testimonials or customer claims exist; none may be invented.

## Product Principles
1. State first: what is running, what needs attention, then the one action that resolves it.
2. The repository is the source of truth; anything only on the device is shown as at risk.
3. One login: Home Assistant's. Secrets appear only where the signed-in owner is.
4. Nothing destructive without saying what it does (Apply migrations restarts the add-on).

## Accessibility & Inclusion
Keyboard operable with visible focus; works at 320 px inside the Home Assistant app on a phone;
respects reduced motion; text contrast at least WCAG AA on the dark panel.

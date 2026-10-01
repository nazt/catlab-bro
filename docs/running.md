# Running it

## Without Docker

Needs the `pocketbase` binary (the version pinned in the Dockerfile).

```sh
scripts/provision.sh       # creates pocketbase/pb_data, the logins, prints the banner once
pocketbase serve --dir pocketbase/pb_data \
  --migrationsDir pocketbase/pb_migrations --hooksDir pocketbase/pb_hooks
```

## As a Home Assistant add-on

The repository root is also a Home Assistant add-on repository: use the README's **Add the
repository** button (or **Settings → Add-ons → Add-on store → ⋮ → Repositories** and the repo
URL), install, start, and read the **Log** tab for the logins.

- **Sidebar panel with auto-login:** the add-on appears in the sidebar; opening it signs a Home
  Assistant user in to the PocketBase dashboard as the admin (`auto_login`, trusted only from
  Supervisor's ingress proxy). The landing page is `pocketbase/pb_public/index.html`.
- **Prebuilt image (public repos):** the init workflow sets `image:` in the add-on's
  `config.yaml` and `.github/workflows/addon-image.yml` pushes
  `ghcr.io/<owner>/{arch}-addon-<slug>` for amd64 and aarch64, so Home Assistant pulls instead of
  building. **GHCR packages start private**: after the first run, set each package to *Public*
  (Packages → package → Package settings → Change visibility). Release a new image by bumping
  `version:` in `config.yaml`. Private repos have no `image:` line and build on the device.

- **Migrations live in the repo.** Add them to `pocketbase/pb_migrations/` and push: the
  `addon-image` workflow publishes a new version (bumping the patch number itself if you did not),
  CI regenerates `collections.json`, and Home Assistant offers the update, which applies them.
  The panel shows the running version and the commit it was built from.
- **Drop-in migrations are a hotfix path:** put a `.js` file in
  `/addon_configs/<this add-on>/pb_migrations` (Samba or File editor) or use **Upload a migration**
  in the panel, then **Apply migrations** (restarts the add-on). Until it is committed, the panel
  marks it *not in the repo yet* with **Commit to repo ↗** (GitHub's editor, pre-filled, same
  file name) and **Download**. Once the next version ships it as built-in, the drop-in is ignored
  and never runs twice. Locally, `compose.yaml` mounts `./extra` the same way.

- **Your app's UI at `/`:** `ui/` holds an example web app (plain HTML, signs in with the app
  login). The `ui-release` workflow publishes it as a GitHub release `ui-v<ui/VERSION>` with a
  `dist.zip`; bump `ui/VERSION` to release. At every start the add-on loads the release named by
  `ui_version` (`latest`, a tag, a full URL, or `bundled` for none) from `ui_repo` (default: this
  repository) and serves it at `/`, so the sidebar panel opens your app. The admin page
  (auto-login, setup QR, migrations) moves to **`/_setup/`**. While running, a newer release shows
  up there (and as a Home Assistant notification) with **Update UI**, which swaps it in without a
  restart; the previous build is kept as `old`. Replace `ui/` with any framework's build: the zip
  needs `index.html` at its root and relative URLs (it runs under the ingress prefix).

Details in [`addon/catlab_bro/DOCS.md`](../addon/catlab_bro/DOCS.md).

## On an existing PocketBase

No container: in the existing server's dashboard, **Settings → Import collections**, paste
`pocketbase/collections.json` and **merge** (don't delete the other collections). The rules
enforce ownership on their own, so hooks are optional; copy `pocketbase/pb_hooks/` into the
server's `pb_hooks` only if you want the `app-user` command or your own hooks. Create an app
login under **users**. Tested with PocketBase v0.40.4; needs v0.23 or later.

## Network

Compose binds `127.0.0.1` only. For other devices on your LAN, drop the `127.0.0.1:` prefix in
`compose.yaml` and set `PUBLIC_URL`. Before exposing it to the internet, put HTTPS in front
(reverse proxy or tunnel).


## Security notes

- Never commit `pocketbase/pb_data/`, `.env` or `initial-credentials.txt`. `.gitignore` covers
  them and the privacy check refuses them.
- Public sign-up is off: logins are created by an admin or by provisioning.
- Rules are written to hold without hooks; keep it that way (see `AGENTS.md`).


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


# Catlab Bro

[![ci](https://github.com/nazt/catlab-bro/actions/workflows/ci.yml/badge.svg)](https://github.com/nazt/catlab-bro/actions/workflows/ci.yml)
![PocketBase](https://img.shields.io/badge/PocketBase-v0.40.4-b8dbe4)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

<!-- ha-buttons -->
[![Add the repository to my Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fnazt%2Fcatlab-bro)
[![Open the add-on in my Home Assistant](https://my.home-assistant.io/badges/supervisor_addon.svg)](https://my.home-assistant.io/redirect/supervisor_addon/?addon=da702f49_catlab_bro&repository_url=https%3A%2F%2Fgithub.com%2Fnazt%2Fcatlab-bro)
<!-- /ha-buttons -->

A new [PocketBase](https://pocketbase.io) backend per project, in one click: **Use this
template**, then `docker compose up --build`. Logins are provisioned on first start, and the same
image installs as a Home Assistant add-on with a sidebar panel that signs you in, prebuilt on GHCR.

## Quick start

```sh
docker compose up --build -d
docker compose logs        # admin UI URL + admin and app logins, random passwords, shown ONCE
```

`docker compose down -v` deletes everything; the next start provisions again.

## Deploy to Home Assistant

The buttons above add the repository to Home Assistant. From a checkout, one command installs or
updates the add-on **and starts it** (Home Assistant never starts an add-on after installing it),
then waits until PocketBase answers:

```sh
scripts/ha-deploy.mjs --ha http://homeassistant.local:8123 --wait   # --wait: right after git push
```

It signs in with a long-lived access token kept in `~/.config/ha-deploy/<host>.token` (mode 600).

## Make it your project

A new repo from this template **names itself after the repository** (`catlab-bro` → "Catlab
Bro") and opens a **setup issue** with the rest of the checklist:

```sh
# replace the `notes` example in pocketbase/pb_migrations/ + its checks in scripts/e2e.mjs
scripts/export-collections.sh && scripts/sync-addon.sh
scripts/local-e2e.sh       # → LOCAL E2E: ALL PASS
```

Or tell a coding agent: *"Set up this template for my project, following AGENTS.md."*

## What's inside

| | |
|---|---|
| `pocketbase/` | migrations, hooks, `collections.json`: the part you edit |
| `addon/<slug>/` | the image (pinned, SHA-256-verified PocketBase) and Home Assistant add-on |
| `scripts/` | provisioning, rename, e2e tests, sync, Home Assistant deploy, PocketBase version bump, privacy check |
| `AGENTS.md` | instructions for AI coding agents |

## Docs

- [Running it](docs/running.md): without Docker, as a Home Assistant add-on, on an existing PocketBase, network and security
- [Repository layout](docs/layout.md): every file and what it does
- [Testing](docs/testing.md): what the e2e covers and how to bump PocketBase

MIT, see [LICENSE](LICENSE).

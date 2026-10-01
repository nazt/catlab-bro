This repository was created from the PocketBase backend template and already named
**__NAME__** after the repository (`project.env`; change it with `scripts/rename.sh`).
Work through this list once to finish the setup; an AI coding agent can do it for you (see the bottom).

## Checklist

- [x] **Named** after the repository by the init workflow (rename again with `scripts/rename.sh` if you like)
- [ ] **README:** rewrite the intro for this project
- [ ] **Schema:** replace the example `notes` collection in `pocketbase/pb_migrations/` with your own
      collections and owner rules (pattern in `AGENTS.md` → *Add a collection*)
- [ ] **Tests:** matching checks in `scripts/e2e.mjs`
- [ ] **Regenerate:** `scripts/export-collections.sh` and `scripts/sync-addon.sh`
- [ ] **Verify:** `scripts/local-e2e.sh` → `LOCAL E2E: ALL PASS`, `python3 scripts/privacy_check.py`
- [ ] **Run it:** `docker compose up --build -d`, logins in `docker compose logs` (shown once)
- [ ] **Home Assistant:** in a public repo the init workflow switched the add-on to a prebuilt GHCR
      image and started `addon-image`. GHCR packages start **private**: once that run is green, open
      [your packages](https://github.com/__OWNER__?tab=packages) → each `*-addon-*` package →
      *Package settings* → *Change visibility* → **Public** (the API cannot do it). Then use the
      README's *Add the repository* button; the add-on appears in the sidebar and signs you in.

## Let an AI do it

Open the repo in Claude Code, Codex or another coding agent and say:

> Set up this template for my project, following AGENTS.md. Work on issue #__ISSUE__.

Describe the data in a comment here first (collections, fields, who may read/write) so the agent
can build the real schema; without it, it keeps the `notes` example and lists its questions in the PR.

## Never commit

`pb_data/`, `.env`, `initial-credentials.txt`: the logins and data of your running server.
Do not paste the generated passwords into this issue.

---
Opened automatically by `.github/workflows/init.yml`. Close it when the checklist is done.

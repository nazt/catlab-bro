# Repository layout

```
├── pocketbase/                 what PocketBase loads: edit here
│   ├── pb_migrations/          schema + access rules (the `notes` example)
│   ├── pb_hooks/               optional server code: the `app-user` command, an example hook
│   └── collections.json        the same schema for "Import collections" (generated)
├── addon/<slug>/               the image: Dockerfile, run.sh, Home Assistant add-on files
│   └── rootfs/                 generated copy of pocketbase/ + provision.sh (never edit)
├── ui/                         example app UI (plain HTML) -> release ui-v<VERSION> dist.zip, served at /
├── scripts/
│   ├── provision.sh            first-start logins, random passwords, idempotent
│   ├── e2e.mjs, local-e2e.sh   provisioning, rules, realtime and import tests
│   ├── rename.sh               give the project its own name
│   ├── ha-buttons.sh           point the Home Assistant links (repository.yaml, README) at a repo URL
│   ├── sync-addon.sh           copy pocketbase/ into the add-on (--check compares)
│   ├── export-collections.sh   regenerate collections.json
│   ├── bump-pocketbase.sh      pin a new PocketBase version + checksums
│   └── privacy_check.py        no paths, private IPs, credentials or data in the repo
├── .github/                    CI, the init workflow and the setup issue text
├── compose.yaml, .env.example  standalone run
├── project.env                 project identity: name, slug, port, default login emails
├── repository.yaml             makes the repo a Home Assistant add-on repository
└── AGENTS.md, CLAUDE.md        instructions for AI coding agents
```


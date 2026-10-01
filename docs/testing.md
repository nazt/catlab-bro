# Testing

```sh
scripts/local-e2e.sh                 # needs pocketbase, node (or RUNNER=bun), python3, curl
python3 scripts/privacy_check.py
```

`local-e2e.sh` provisions a fresh server and checks the banner, the 600 credentials file and
idempotence. It then runs the rules tests three ways: with hooks, without hooks, and on a plain
PocketBase that imported `collections.json`. CI runs the same, plus a Docker build check, a
compose smoke test and the add-on sync check.

To move to a new PocketBase release: `scripts/bump-pocketbase.sh <version>`, then the tests.


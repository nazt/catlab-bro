#!/usr/bin/env bash
# Regenerate collections.json from pocketbase/pb_migrations/: migrate a throwaway PocketBase, export every
# non-system collection in the Dashboard "Import collections" format, stop, delete it.
# Run after changing pocketbase/pb_migrations/ (e2e.mjs fails when the file and the schema differ).
# The `users` collection is left out on purpose: an existing PocketBase keeps its own.
# Needs: pocketbase on PATH (or $POCKETBASE), python3, curl.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
pb="${POCKETBASE:-pocketbase}"
tmp="$(mktemp -d)"
port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')"
pid=""
trap 'if [ -n "$pid" ]; then kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; fi; rm -rf "$tmp"' EXIT
pass="export-$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"
"$pb" superuser upsert export@example.invalid "$pass" --dir "$tmp" --migrationsDir "$here/pocketbase/pb_migrations" >/dev/null
"$pb" serve --dir "$tmp" --migrationsDir "$here/pocketbase/pb_migrations" --hooksDir "$tmp/no-hooks" \
  --http "127.0.0.1:$port" >/dev/null 2>&1 &
pid=$!
for _ in $(seq 1 75); do curl -fs "http://127.0.0.1:$port/api/health" >/dev/null 2>&1 && break; sleep 0.2; done
PB="http://127.0.0.1:$port" PASS="$pass" OUT="$here/pocketbase/collections.json" python3 - <<'PY'
import json, os, urllib.request
base = os.environ["PB"]
def req(path, body=None, token=None):
    r = urllib.request.Request(base + path, data=json.dumps(body).encode() if body else None,
                               headers={"Content-Type": "application/json", **({"Authorization": token} if token else {})})
    return json.load(urllib.request.urlopen(r))
token = req("/api/collections/_superusers/auth-with-password",
            {"identity": "export@example.invalid", "password": os.environ["PASS"]})["token"]
out = []
for c in req("/api/collections?perPage=500&sort=name", token=token)["items"]:
    if c.get("system") or c["name"] == "users":
        continue
    c.pop("created", None); c.pop("updated", None)
    out.append(c)
with open(os.environ["OUT"], "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
print("wrote collections.json:", ", ".join(c["name"] for c in out))
PY

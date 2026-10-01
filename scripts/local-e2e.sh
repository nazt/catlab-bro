#!/usr/bin/env bash
# Full local test without Docker. Temp dirs on free localhost ports, deleted afterwards:
#   1. provisioning: fresh dir -> provision (random passwords, banner once, file mode 600)
#      -> second run idempotent -> a password changed later is never reset
#   2. this repo's server (migrations + hooks) -> e2e.mjs with the provisioned app login
#   3. same migrations with hooks DISABLED -> e2e.mjs (rules alone must hold)
#   4. "existing PocketBase": plain server, no migrations, no hooks -> import collections.json
#      through the API (merge, like Dashboard -> Import collections) -> e2e.mjs
#   5. the add-on copy is in sync (scripts/sync-addon.sh --check)
# Needs: pocketbase (the version pinned in the Dockerfile) on PATH or in $POCKETBASE,
# node 18+ (or bun: RUNNER=bun), python3, curl.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
runner="${RUNNER:-node}"
pb="${POCKETBASE:-pocketbase}"
tmp="$(mktemp -d)"
port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')"
url="http://127.0.0.1:$port"
pid=""
fails=0
passes=0
cleanup() { if [ -n "$pid" ]; then kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; fi; rm -rf "$tmp"; }
trap cleanup EXIT
result() { if [ "$1" = 0 ]; then echo "PASS $2"; passes=$((passes + 1)); else echo "FAIL $2"; fails=$((fails + 1)); fi; }
pe() { sed -n "s/^$1=//p" "$here/project.env" | tail -n 1 | sed 's/^"\(.*\)"$/\1/'; }
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }  # GNU first: GNU "stat -f" means filesystem info
wait_health() { for _ in $(seq 1 75); do curl -fs "$url/api/health" >/dev/null 2>&1 && return 0; sleep 0.2; done; return 1; }
serve() { # data-dir migrations-dir hooks-dir log
  "$pb" serve --dir "$1" --migrationsDir "$2" --hooksDir "$3" --publicDir "$here/pocketbase/pb_public" \
    --http "127.0.0.1:$port" > "$4" 2>&1 &
  pid=$!
  wait_health
}
stop() { kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; pid=""; }
e2e() { "$runner" "$here/scripts/e2e.mjs" | sed 's/^/    /'; return "${PIPESTATUS[0]}"; }

echo ".... pocketbase $("$pb" --version | awk '{print $NF}'), data dir $tmp, port $port"
data="$tmp/pb_data"
creds="$data/initial-credentials.txt"
kv() { sed -n "s/^$1=//p" "$creds"; }

# --- 1. provisioning -----------------------------------------------------------------------
first="$(POCKETBASE="$pb" "$here/scripts/provision.sh" --dir "$data" --url "$url")"; rc=$?
result "$rc" "provision on a fresh dir"
echo "$first" | grep -q "credentials shown ONCE"; result $? "provision prints the banner once"
echo "$first" | grep -q "^ $(pe PROJECT_NAME) ready"; result $? "banner names the project (PROJECT_NAME)"
echo "$first" | grep -qF " admin UI    : $url/_/"; result $? "banner shows the admin UI URL"
echo "$first" | grep -qF " admin login : $(pe ADMIN_EMAIL) / $(kv admin_password)" \
  && echo "$first" | grep -qF " app login   : $(pe APP_USER_EMAIL) / $(kv app_password)"
result $? "banner shows admin + app logins (emails from project.env)"
[ "$(mode "$creds")" = 600 ]; result $? "initial-credentials.txt is mode 600"
ap="$(kv admin_password)"; up="$(kv app_password)"
[[ "$ap" =~ ^[A-Za-z0-9]{24}$ && "$up" =~ ^[A-Za-z0-9]{24}$ && "$ap" != "$up" ]]
result $? "generated passwords are 24 random characters, distinct"

other="$(POCKETBASE="$pb" "$here/scripts/provision.sh" --dir "$tmp/other" --url "$url" 2>&1)"
[ "$(sed -n 's/^admin_password=//p' "$tmp/other/initial-credentials.txt")" != "$(kv admin_password)" ]
result $? "another fresh dir gets different passwords (never a fixed default)"
rm -rf "$tmp/other"

before="$(cat "$creds")"
second="$(POCKETBASE="$pb" "$here/scripts/provision.sh" --dir "$data" --url "$url")"; rc=$?
result "$rc" "provision second run"
! echo "$second" | grep -q "credentials shown ONCE" && ! echo "$second" | grep -qF "$(kv admin_password)" \
  && [ "$before" = "$(cat "$creds")" ]
result $? "second run is idempotent (nothing regenerated or printed)"

# A password changed later (as if in the admin UI) must survive the next provisioning.
changed="changed-$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"
"$pb" app-user "$(kv app_email)" "$changed" --dir "$data" --migrationsDir "$here/pocketbase/pb_migrations" \
  --hooksDir "$here/pocketbase/pb_hooks" >/dev/null
POCKETBASE="$pb" "$here/scripts/provision.sh" --dir "$data" --url "$url" >/dev/null; rc=$?
result "$rc" "provision after a password change"

# --- 2. migrations + hooks ---------------------------------------------------------------------
serve "$data" "$here/pocketbase/pb_migrations" "$here/pocketbase/pb_hooks" "$tmp/serve.log"; result $? "server starts (migrations + hooks)"
code="$(curl -s -o /dev/null -w '%{http_code}' -X POST "$url/api/collections/users/auth-with-password" \
  -H 'Content-Type: application/json' -d "{\"identity\":\"$(kv app_email)\",\"password\":\"$changed\"}")"
[ "$code" = 200 ]; result $? "later-changed app password was not reset by provisioning"
PB_URL="$url" PB_ADMIN_EMAIL="$(kv admin_email)" PB_ADMIN_PASSWORD="$(kv admin_password)" \
  PB_APP_EMAIL="$(kv app_email)" PB_APP_PASSWORD="$changed" e2e
result $? "e2e.mjs (migrations + hooks, provisioned logins)"
stop

# --- 2b. Home Assistant sidebar auto-login (pb_hooks/lib/halogin.js) ---------------------------
# The trusted ingress peer is 127.0.0.1 here (172.30.32.2 in Home Assistant).
ha() { curl -s -o "$tmp/ha.json" -w '%{http_code}' "$url/api/app/ha-login" "$@"; }
ING=(-H 'X-Ingress-Path: /api/hassio_ingress/test')
HA_AUTO_LOGIN=true HA_INGRESS_PEER=127.0.0.1 HA_USER_IDS=ha-user-1 ADMIN_EMAIL="$(kv admin_email)" \
  serve "$data" "$here/pocketbase/pb_migrations" "$here/pocketbase/pb_hooks" "$tmp/serve-ha.log"
result $? "server starts (auto-login on, test peer 127.0.0.1)"
[ "$(ha)" = 403 ]; result $? "ha-login without Home Assistant headers is refused"
[ "$(ha "${ING[@]}" -H 'X-Remote-User-Id: ha-user-2')" = 403 ]; result $? "ha-login refuses a user outside ha_user_ids"
[ "$(ha "${ING[@]}" -H 'X-Remote-User-Id: ha-user-1')" = 200 ] \
  && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["token"] and d["record"]["email"]==sys.argv[2] and d["record"]["collectionName"]=="_superusers"' \
     "$tmp/ha.json" "$(kv admin_email)"
result $? "ha-login through ingress returns the admin's dashboard session"
curl -fs "$url/" | grep -q 'api/app/ha-login'; result $? "landing page (pb_public) is served at / and uses ha-login"
stop
HA_AUTO_LOGIN=true HA_INGRESS_PEER=192.0.2.1 ADMIN_EMAIL="$(kv admin_email)" \
  serve "$data" "$here/pocketbase/pb_migrations" "$here/pocketbase/pb_hooks" "$tmp/serve-ha2.log"
[ "$(ha "${ING[@]}" -H 'X-Remote-User-Id: ha-user-1')" = 403 ]; result $? "ha-login refuses the same headers from any other peer (the published port)"
stop
serve "$data" "$here/pocketbase/pb_migrations" "$here/pocketbase/pb_hooks" "$tmp/serve-ha3.log"
[ "$(ha "${ING[@]}" -H 'X-Remote-User-Id: ha-user-1')" = 404 ]; result $? "ha-login is off unless HA_AUTO_LOGIN=true (standalone)"
stop

# --- 3. same schema, hooks disabled ------------------------------------------------------------
mkdir -p "$tmp/no-hooks"
serve "$data" "$here/pocketbase/pb_migrations" "$tmp/no-hooks" "$tmp/serve-nohooks.log"; result $? "server starts (hooks disabled)"
PB_URL="$url" PB_ADMIN_EMAIL="$(kv admin_email)" PB_ADMIN_PASSWORD="$(kv admin_password)" NO_HOOKS=1 e2e
result $? "e2e.mjs with hooks disabled"
stop

# --- 4. existing PocketBase: import collections.json -------------------------------------------
echo ".... existing-PocketBase mode: no migrations, no hooks, schema imported from collections.json"
shared="$tmp/shared"
mkdir -p "$shared/data" "$shared/no-migrations"
spass="shared-$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"
"$pb" superuser upsert shared-admin@example.invalid "$spass" --dir "$shared/data" \
  --migrationsDir "$shared/no-migrations" >/dev/null
serve "$shared/data" "$shared/no-migrations" "$tmp/no-hooks" "$tmp/serve-shared.log"; result $? "plain server starts"
PB="$url" PASS="$spass" JSONFILE="$here/pocketbase/collections.json" python3 - <<'PY'
import json, os, sys, urllib.request
base = os.environ["PB"]
token_req = urllib.request.Request(base + "/api/collections/_superusers/auth-with-password",
    data=json.dumps({"identity": "shared-admin@example.invalid", "password": os.environ["PASS"]}).encode(),
    headers={"Content-Type": "application/json"})
token = json.load(urllib.request.urlopen(token_req))["token"]
collections = json.load(open(os.environ["JSONFILE"]))
r = urllib.request.Request(base + "/api/collections/import", method="PUT",
    data=json.dumps({"collections": collections, "deleteMissing": False}).encode(),
    headers={"Content-Type": "application/json", "Authorization": token})
with urllib.request.urlopen(r) as resp:
    sys.exit(0 if resp.status == 204 else 1)
PY
result $? "collections.json imports into a plain PocketBase (merge)"
PB_URL="$url" PB_ADMIN_EMAIL="shared-admin@example.invalid" PB_ADMIN_PASSWORD="$spass" \
  NO_HOOKS=1 SHARED_PB=1 e2e
result $? "e2e.mjs on the imported schema without hooks"
stop

# --- 5. add-on copy ----------------------------------------------------------------------------
"$here/scripts/sync-addon.sh" --check >/dev/null; result $? "add-on copy and identity in sync (sync-addon.sh --check)"

if [ "$fails" -ne 0 ]; then
  echo "---- server logs"; tail -n 30 "$tmp"/serve*.log 2>/dev/null
  echo "LOCAL E2E: $fails FAILED, $passes passed"; exit 1
fi
echo "LOCAL E2E: ALL PASS ($passes steps)"

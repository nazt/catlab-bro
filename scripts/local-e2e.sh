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
spid=""
cleanup() { for p in "$pid" "$spid"; do if [ -n "$p" ]; then kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; fi; done; rm -rf "$tmp"; }
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
# page PATH TEXT: the page at PATH contains TEXT. Not "curl | grep -q": under pipefail, grep -q
# quitting at the first match makes curl fail with a broken pipe (exit 23) on a large page.
page() { curl -fs -o "$tmp/page.html" "$url$1" && grep -q -- "$2" "$tmp/page.html"; }
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
atok="$(curl -s -X POST "$url/api/collections/_superusers/auth-with-password" -H 'Content-Type: application/json' \
  -d "{\"identity\":\"$(kv admin_email)\",\"password\":\"$(kv admin_password)\"}" | python3 -c 'import json,sys;print(json.load(sys.stdin)["token"])')"
seeded="$(curl -s "$url/api/collections/notes/records?perPage=1&filter=title%3D'Welcome'" -H "Authorization: $atok" | python3 -c 'import json,sys;print(json.load(sys.stdin)["totalItems"])')"
[ -f "$data/.seeded" ] && [ "$seeded" = 1 ]; result $? "seed: starter notes loaded once (pocketbase/seed), not duplicated by later runs"
PB_URL="$url" PB_ADMIN_EMAIL="$(kv admin_email)" PB_ADMIN_PASSWORD="$(kv admin_password)" \
  PB_APP_EMAIL="$(kv app_email)" PB_APP_PASSWORD="$changed" e2e
result $? "e2e.mjs (migrations + hooks, provisioned logins)"
stop

# --- 2b. Home Assistant sidebar auto-login (pb_hooks/lib/halogin.js) ---------------------------
# The trusted ingress peer is 127.0.0.1 here (172.30.32.2 in Home Assistant).
ha() { curl -s -o "$tmp/ha.json" -w '%{http_code}' "$url/api/app/ha-login" "$@"; }
ING=(-H 'X-Ingress-Path: /api/hassio_ingress/test')
HA_AUTO_LOGIN=true HA_INGRESS_PEER=127.0.0.1 HA_USER_IDS=ha-user-1 ADMIN_EMAIL="$(kv admin_email)" \
  CREDENTIALS_FILE="$creds" PUBLIC_URL="$url" SETUP_SCHEME="$(pe SETUP_SCHEME)" \
  serve "$data" "$here/pocketbase/pb_migrations" "$here/pocketbase/pb_hooks" "$tmp/serve-ha.log"
result $? "server starts (auto-login on, test peer 127.0.0.1)"
[ "$(ha)" = 403 ]; result $? "ha-login without Home Assistant headers is refused"
[ "$(ha "${ING[@]}" -H 'X-Remote-User-Id: ha-user-2')" = 403 ]; result $? "ha-login refuses a user outside ha_user_ids"
[ "$(ha "${ING[@]}" -H 'X-Remote-User-Id: ha-user-1')" = 200 ] \
  && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["token"] and d["record"]["email"]==sys.argv[2] and d["record"]["collectionName"]=="_superusers"' \
     "$tmp/ha.json" "$(kv admin_email)"
result $? "ha-login through ingress returns the admin's dashboard session"
page "/" 'api/app/ha-login'; result $? "landing page (pb_public) is served at / and uses ha-login"
curl -sI "$url/_/" | grep -i '^content-security-policy:' | grep -q "frame-ancestors 'self'"
result $? "dashboard may be framed by its own origin (the Home Assistant panel), not by others"
tok="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["token"])' "$tmp/ha.json")"
setup="$(curl -s "$url/api/app/setup" -H "Authorization: $tok")"
echo "$setup" | python3 -c 'import json,sys; d=json.load(sys.stdin); import urllib.parse as u
assert d["app_email"] and d["app_password"] and d["link"].startswith(sys.argv[1]+"://setup?u=")
assert u.parse_qs(u.urlsplit(d["link"]).query)["p"][0] == d["app_password"]' "$(pe SETUP_SCHEME)"
result $? "setup: the panel (superuser session) gets the app login and its <scheme>://setup link"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$url/api/app/setup")" = 401 ]; result $? "setup: refused without a superuser session"
stop
HA_AUTO_LOGIN=true HA_INGRESS_PEER=192.0.2.1 ADMIN_EMAIL="$(kv admin_email)" \
  serve "$data" "$here/pocketbase/pb_migrations" "$here/pocketbase/pb_hooks" "$tmp/serve-ha2.log"
[ "$(ha "${ING[@]}" -H 'X-Remote-User-Id: ha-user-1')" = 403 ]; result $? "ha-login refuses the same headers from any other peer (the published port)"
stop
# No ha_user_ids: the first Home Assistant user to open the panel claims it; everyone else is refused.
HA_AUTO_LOGIN=true HA_INGRESS_PEER=127.0.0.1 HA_OWNER_FILE="$tmp/ha-owner" ADMIN_EMAIL="$(kv admin_email)" \
  serve "$data" "$here/pocketbase/pb_migrations" "$here/pocketbase/pb_hooks" "$tmp/serve-claim.log"
[ "$(ha "${ING[@]}" -H 'X-Remote-User-Id: first-user')" = 200 ] && [ "$(cat "$tmp/ha-owner")" = first-user ] \
  && [ "$(mode "$tmp/ha-owner")" = 600 ]
result $? "first panel user claims the add-on (owner file written, mode 600)"
[ "$(ha "${ING[@]}" -H 'X-Remote-User-Id: second-user')" = 403 ]; result $? "any other Home Assistant user is refused after the claim"
[ "$(ha "${ING[@]}" -H 'X-Remote-User-Id: first-user')" = 200 ]; result $? "the owner keeps getting in"
stop
serve "$data" "$here/pocketbase/pb_migrations" "$here/pocketbase/pb_hooks" "$tmp/serve-ha3.log"
[ "$(ha "${ING[@]}" -H 'X-Remote-User-Id: ha-user-1')" = 404 ]; result $? "ha-login is off unless HA_AUTO_LOGIN=true (standalone)"
stop

# --- 2c. drop-in migrations (merge-extra.sh + /api/app/migrations) -------------------------------
# On a copy of the data: the drop-in schema must not leak into the steps after this one.
mdata="$tmp/data-mig"; cp -R "$data" "$mdata"
extra="$tmp/extra"; mkdir -p "$extra/pb_migrations"
cat > "$extra/pb_migrations/1790900000_dropin_demo.js" <<'JS'
migrate((app) => {
  app.save(new Collection({ type: "base", name: "dropin_demo", fields: [{ type: "text", name: "label" }] }))
}, (app) => { app.delete(app.findCollectionByNameOrId("dropin_demo")) })
JS
mig() { curl -s "$url/api/app/migrations" -H "Authorization: $atok"; }
EXTRA_DIR="$extra" BUILTIN_MIGRATIONS="$here/pocketbase/pb_migrations" REPO_URL=https://github.com/example/repo \
  serve "$mdata" "$here/pocketbase/pb_migrations" "$here/pocketbase/pb_hooks" "$tmp/serve-mig1.log"
mig | python3 -c 'import json,sys; d=json.load(sys.stdin); f=d["files"][0]
assert not f["in_repo"] and d["uncommitted"]==1 and "migrate(" in f["content"]
assert f["commit_url"].startswith("https://github.com/example/repo/new/main/pocketbase/pb_migrations?filename=1790900000_dropin_demo.js&value=")'
result $? "migrations: a drop-in not in the repo gets a Commit-to-repo link (same name, pre-filled content)"
curl -s "$url/api/app/info" -H "Authorization: $atok" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["version"]=="dev" and d["repo"]=="https://github.com/example/repo"'
result $? "info: the panel learns the running version/commit and the repository"
[ "$(mig | python3 -c 'import json,sys;print(json.load(sys.stdin)["pending"])')" = 1 ]; result $? "migrations: a dropped-in file shows as pending"
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$url/api/app/restart" -H "Authorization: $atok")" = 501 ]
result $? "migrations: restart outside Home Assistant says to restart the container (501)"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$url/api/app/migrations")" = 401 ]; result $? "migrations: refused without a superuser session"
up() { curl -s -o /dev/null -w '%{http_code}' -X POST "$url/api/app/migrations" -H "Authorization: $atok" -H 'Content-Type: application/json' -d "$1"; }
[ "$(up '{"name":"1790900001_uploaded.js","content":"migrate((app) => {}, (app) => {})"}')" = 201 ] && [ -f "$extra/pb_migrations/1790900001_uploaded.js" ] \
  && [ "$(up '{"name":"../evil.js","content":"migrate(1)"}')" = 400 ] && [ "$(up '{"name":"1790900002_x.js","content":"rm -rf"}')" = 400 ] \
  && [ "$(up '{"name":"1790900001_uploaded.js","content":"migrate((app) => {}, (app) => {})"}')" = 409 ]
result $? "migrations: upload writes a valid file; refuses paths, non-migrations and duplicates"
stop
"$here/scripts/merge-extra.sh" "$here/pocketbase" "$extra" "$tmp/run" >/dev/null
EXTRA_DIR="$extra" serve "$mdata" "$tmp/run/pb_migrations" "$tmp/run/pb_hooks" "$tmp/serve-mig2.log"
[ "$(mig | python3 -c 'import json,sys;print(json.load(sys.stdin)["pending"])')" = 0 ] \
  && [ "$(curl -s -o /dev/null -w '%{http_code}' "$url/api/collections/dropin_demo" -H "Authorization: $atok")" = 200 ] \
  && [ "$(mig | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["files"]))')" = 2 ]
result $? "migrations: after merge + restart the drop-in is applied (collection exists, nothing pending)"
stop
# Committed: the same name is now built-in (the next image) -> shown as in the repo, nothing pending.
mkdir -p "$tmp/builtin" && cp "$here/pocketbase/pb_migrations/"*.js "$extra/pb_migrations/1790900000_dropin_demo.js" "$tmp/builtin/"
EXTRA_DIR="$extra" BUILTIN_MIGRATIONS="$tmp/builtin" serve "$mdata" "$tmp/run/pb_migrations" "$tmp/run/pb_hooks" "$tmp/serve-mig3.log"
mig | python3 -c 'import json,sys; d=json.load(sys.stdin); f=[x for x in d["files"] if x["name"]=="1790900000_dropin_demo.js"][0]
assert f["in_repo"] and "commit_url" not in f and d["pending"]==0'
result $? "migrations: once committed under the same name it shows as in the repo (drop-in can go)"

stop

# --- 2d. app UI at "/" (ui/ as a release would ship it), the landing page at /_setup/ -----------
uidir="$tmp/ui"; mkdir -p "$uidir/current"; cp -R "$here/ui/." "$uidir/current/"; rm -f "$uidir/current/VERSION"
tag="ui-v$(tr -d ' \n' < "$here/ui/VERSION")"
sed "s/%UI_VERSION%/$tag/" "$here/ui/index.html" > "$uidir/current/index.html"
cp -R "$here/pocketbase/pb_public" "$uidir/current/_setup"
UI_DIR="$uidir" UI_REPO=example/repo UI_CHANNEL="$tag" PROJECT_NAME="E2E Project" \
  "$pb" serve --dir "$mdata" --migrationsDir "$tmp/run/pb_migrations" --hooksDir "$here/pocketbase/pb_hooks" \
  --publicDir "$uidir/current" --http "127.0.0.1:$port" > "$tmp/serve-ui.log" 2>&1 &
pid=$!; wait_health
page "/" "name=\"ui-version\" content=\"$tag\""; result $? "ui: the app UI is served at / and carries its release tag"
page "/_setup/" 'api/app/ha-login'; result $? "ui: the landing page moves to /_setup/"
curl -sI "$url/" | tr -d '\r' | grep -qi '^cache-control: no-cache$' \
  && [ "$(curl -s -o /dev/null -w '%{http_code}' "$url/fonts/OFL.txt")" = 200 ] && ! curl -sI "$url/fonts/OFL.txt" | grep -qi '^cache-control: no-cache'
result $? "ui: HTML is revalidated on every visit (no stale page after an update); assets are not"
curl -s "$url/api/app/ui" -H "Authorization: $atok" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["managed"] and d["installed"]==sys.argv[1] and d["channel"]==sys.argv[1] and not d["update"]' "$tag"
result $? "ui: status reports the running release (pinned: no update offered)"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$url/api/app/ui")" = 401 ]; result $? "ui: status refused without a superuser session"
curl -fs "$url/api/app/about" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d=={"name":"E2E Project","ui":{"installed":sys.argv[1],"latest":"","update":False}}, d' "$tag"
result $? "ui: /api/app/about (public) gives the app its name and its version, nothing more"
src() { curl -s -o "$tmp/src.json" -w '%{http_code}' -X POST "$url/api/app/ui/source" -H 'Content-Type: application/json' "$@"; }
[ "$(src -d '{"source":"latest"}')" = 401 ]; result $? "ui: the source cannot be set without a superuser session"
[ "$(src -H "Authorization: $atok" -d '{"source":"https://x.invalid/a'"'"'b.zip"}')" = 400 ]
result $? "ui: a source that could break out of the shell is refused (400)"
[ "$(src -H "Authorization: $atok" -d '{"source":"ui-v9.9.9"}')" = 501 ]
result $? "ui: outside Home Assistant the source is not saved (501: set UI_VERSION)"
stop

# --- 2e. the Home Assistant paths, against a stand-in Supervisor (scripts/fake-supervisor.py) ------
sport="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')"
sup="$tmp/supervisor"; mkdir -p "$sup/files" "$tmp/ui2"
sed "s/%UI_VERSION%/ui-v0.2.0/" "$here/ui/index.html" > "$tmp/ui2/index.html"
python3 -c 'import sys, zipfile; z = zipfile.ZipFile(sys.argv[1], "w"); z.write(sys.argv[2], "index.html"); z.close()' "$sup/files/dist.zip" "$tmp/ui2/index.html"
SUPERVISOR_TOKEN=e2e-token FAKE_VERSION=0.1.8 FAKE_LATEST=0.1.9 FAKE_SLUG=e2e_slug \
  python3 "$here/scripts/fake-supervisor.py" "$sport" "$sup" "$sup/files" 2> "$tmp/supervisor.log" &
spid=$!
for _ in $(seq 1 50); do curl -fs -o /dev/null "http://127.0.0.1:$sport/files/dist.zip" && break; sleep 0.1; done
SUPERVISOR_URL="http://127.0.0.1:$sport" SUPERVISOR_TOKEN=e2e-token UI_DIR="$uidir" UI_REPO=example/repo UI_CHANNEL="$tag" \
  SETUP_SRC="$here/pocketbase/pb_public" \
  "$pb" serve --dir "$mdata" --migrationsDir "$tmp/run/pb_migrations" --hooksDir "$here/pocketbase/pb_hooks" \
  --publicDir "$uidir/current" --http "127.0.0.1:$port" > "$tmp/serve-sup.log" 2>&1 &
pid=$!; wait_health
curl -s "$url/api/app/info" -H "Authorization: $atok" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["update"]=={"available":True,"latest":"0.1.9","slug":"e2e_slug"}, d'
result $? "supervisor: the panel learns that add-on 0.1.9 is out (/addons/self/info)"
zipurl="http://127.0.0.1:$sport/files/dist.zip"
[ "$(src -H "Authorization: $atok" -d "{\"source\":\"$zipurl\"}")" = 200 ] \
  && page "/" 'content="ui-v0.2.0"' && page "/_setup/" 'api/app/ha-login'
result $? "ui source: a dist.zip URL is loaded at once, no restart, the admin page stays at /_setup/"
python3 -c 'import json,sys; o=json.load(open(sys.argv[1])); assert o["ui_version"]==sys.argv[2] and o["admin_email"]=="admin@example.invalid", o' "$sup/options.json" "$zipurl"
result $? "ui source: saved as the add-on's ui_version, the other options kept"
[ "$(src -H "Authorization: $atok" -d "{\"source\":\"http://127.0.0.1:$sport/files/missing.zip\"}")" = 500 ] \
  && grep -q 'could not load' "$tmp/src.json" && page "/" 'content="ui-v0.2.0"' \
  && python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["ui_version"]==sys.argv[2]' "$sup/options.json" "$zipurl"
result $? "ui source: a build that cannot be loaded is refused, not saved, and the running one stays"
[ "$(src -H "Authorization: $atok" -d '{"source":"bundled"}')" = 200 ] \
  && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["restart"] and d["channel"]=="bundled", d' "$tmp/src.json"
result $? "ui source: bundled is saved and asks for a restart (the served folder changes at start)"
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$url/api/app/restart" -H "Authorization: $atok")" = 202 ] \
  && [ "$(grep -c restart "$sup/restarts")" = 1 ]
result $? "restart: the panel asks the Supervisor to restart the add-on"
stop; kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null; spid=""

# --- 2f. one design system: both pages carry the same token block (DESIGN.md) -----------------
tokens() { sed -n '/tokens:start/,/tokens:end/p' "$1"; }
[ -n "$(tokens "$here/ui/index.html")" ] && [ "$(tokens "$here/ui/index.html")" = "$(tokens "$here/pocketbase/pb_public/index.html")" ]
result $? "design: the admin page and the app UI share one token block"

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

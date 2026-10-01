#!/usr/bin/env bash
# One-step provisioning: the PocketBase superuser (admin UI) and one app login (`users` record).
#
# Run it before `pocketbase serve`, or while the server is stopped. The container runs this same
# file on every start (a copy lives in the add-on; scripts/sync-addon.sh keeps it identical).
#
# Passwords are ALWAYS generated randomly, on the first run only:
#   * first run   -> a strong random password per login, written to
#                    <state-dir>/initial-credentials.txt (mode 600) and printed ONCE in a banner.
#   * later runs  -> nothing is touched (a password changed later in the admin UI is never
#                    reset); only the location of the credentials file is printed.
#   * changed email (e.g. ADMIN_EMAIL) -> that login is created with a new random password and
#                    printed once, like a first run.
#
# Usage: scripts/provision.sh [options]
#   --admin-email E       default ADMIN_EMAIL from project.env
#   --app-email E         default APP_USER_EMAIL from project.env
#   --dir D               PocketBase data dir          (default pocketbase/pb_data)
#   --state-dir D         credentials + marker files   (default = --dir)
#   --migrations-dir D    default pocketbase/pb_migrations
#   --hooks-dir D         default pocketbase/pb_hooks (must contain the app-user command)
#   --url U               public base URL for the banner (default http://127.0.0.1:DEFAULT_PORT)
#   --project-name N      banner title (default PROJECT_NAME from project.env)
#   --seed-dir D          starter records loaded ONCE on the first run (default pocketbase/seed)
#   --pocketbase BIN      default: pocketbase on PATH (or $POCKETBASE)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# Repo layout: scripts/provision.sh + ./project.env. Container layout: /opt/app/{provision.sh,project.env}.
if [ -f "$here/project.env" ]; then root="$here"; pbdir="$here"; else root="$(cd "$here/.." && pwd)"; pbdir="$root/pocketbase"; fi

# Read KEY from project.env (KEY=value or KEY="value"); never sources the file.
pe() { [ -f "$root/project.env" ] && sed -n "s/^$1=//p" "$root/project.env" | tail -n 1 | sed 's/^"\(.*\)"$/\1/' || true; }

project_name="$(pe PROJECT_NAME)"; project_name="${project_name:-PocketBase}"
admin_email="$(pe ADMIN_EMAIL)"; admin_email="${admin_email:-admin@example.invalid}"
app_email="$(pe APP_USER_EMAIL)"; app_email="${app_email:-app@example.invalid}"
port="$(pe DEFAULT_PORT)"
base_url="http://127.0.0.1:${port:-8090}"
data_dir="$pbdir/pb_data"
state_dir=""
migrations_dir="$pbdir/pb_migrations"
hooks_dir="$pbdir/pb_hooks"
seed_dir="$pbdir/seed"
pb="${POCKETBASE:-pocketbase}"

while [ $# -gt 0 ]; do
  case "$1" in
    --admin-email) admin_email="$2"; shift 2 ;;
    --app-email) app_email="$2"; shift 2 ;;
    --dir) data_dir="$2"; shift 2 ;;
    --state-dir) state_dir="$2"; shift 2 ;;
    --migrations-dir) migrations_dir="$2"; shift 2 ;;
    --hooks-dir) hooks_dir="$2"; shift 2 ;;
    --url) base_url="$2"; shift 2 ;;
    --project-name) project_name="$2"; shift 2 ;;
    --pocketbase) pb="$2"; shift 2 ;;
    --seed-dir) seed_dir="$2"; shift 2 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "provision: unknown option $1" >&2; exit 2 ;;
  esac
done
[ -n "$state_dir" ] || state_dir="$data_dir"
base_url="${base_url%/}"

mkdir -p "$data_dir" "$state_dir"
creds="$state_dir/initial-credentials.txt"
umask 077

pbrun() {
  "$pb" "$@" --dir "$data_dir" --migrationsDir "$migrations_dir" --hooksDir "$hooks_dir" >/dev/null
}

random_password() {
  # 24 characters from [A-Za-z0-9]: ~142 bits.
  local out=""
  while [ "${#out}" -lt 24 ]; do
    out="$out$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"
  done
  printf '%s' "${out:0:24}"
}

# key=value file helpers (no spaces around '=')
get_kv() { if [ -f "$1" ]; then sed -n "s/^$2=//p" "$1" | tail -n 1; fi; }
set_kv() {
  local file="$1" key="$2" value="$3" tmp
  tmp="$(mktemp "$state_dir/.kv.XXXXXX")"
  if [ -f "$file" ]; then grep -v "^$key=" "$file" > "$tmp" || true; fi
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$file"
}

generated=""

provision() { # role email
  local role="$1" email="$2" password
  if [ "$(get_kv "$creds" "${role}_email")" = "$email" ]; then
    echo "provision: $role login $email already set up."
    return
  fi
  password="$(random_password)"
  if [ "$role" = admin ]; then
    pbrun superuser upsert "$email" "$password"
  else
    pbrun app-user "$email" "$password"
  fi
  if [ ! -f "$creds" ]; then
    printf '# %s: generated initial credentials. Keep private; delete once stored elsewhere.\n' "$project_name" > "$creds"
  fi
  set_kv "$creds" "${role}_email" "$email"
  set_kv "$creds" "${role}_password" "$password"
  generated="$generated $role"
}

provision admin "$admin_email"
provision app "$app_email"
chmod 600 "$creds"

# Starter records, once: seeded when the marker is missing and the seed dir has *.json files.
if [ ! -f "$state_dir/.seeded" ] && ls "$seed_dir"/*.json >/dev/null 2>&1; then
  # console commands do not apply this project's migrations (serve does): create the collections first
  if pbrun migrate up && pbrun app-seed "$app_email" "$seed_dir"; then
    date -u +%FT%TZ > "$state_dir/.seeded"
    echo "provision: starter records loaded from $seed_dir (once)"
  else
    echo "provision: WARNING: loading starter records from $seed_dir failed; PocketBase starts anyway" >&2
  fi
fi

if [ -n "$generated" ]; then
  echo "=================================================================="
  echo " $project_name ready (credentials shown ONCE)"
  echo " admin UI    : $base_url/_/"
  case "$generated" in *admin*)
    echo " admin login : $admin_email / $(get_kv "$creds" admin_password)" ;;
  esac
  case "$generated" in *app*)
    echo " app login   : $app_email / $(get_kv "$creds" app_password)"
    echo " API base    : $base_url/api/" ;;
  esac
  echo " saved to    : $creds (mode 600)"
  echo "=================================================================="
else
  echo "provision: generated initial credentials are in $creds"
fi

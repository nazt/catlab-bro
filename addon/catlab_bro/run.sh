#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# Container entry point: provision the logins, then run PocketBase on port 8090.
#
# Two modes, same image, detected automatically and logged:
#   * Home Assistant add-on: options come from the Supervisor (Configuration tab).
#   * standalone (docker/podman compose, no Supervisor): options come from environment
#     variables ADMIN_EMAIL, APP_USER_EMAIL, PUBLIC_URL. Empty = default from project.env.
# Passwords are never configured: they are generated on the first start, printed once and
# kept in /data/initial-credentials.txt (see /opt/app/provision.sh).
set -e

app=/opt/app
data=/data/pb_data
mkdir -p "$data"

# Read KEY from the baked-in project.env (never sourced, so it cannot clobber the environment).
pe() { sed -n "s/^$1=//p" "$app/project.env" | tail -n 1 | sed 's/^"\(.*\)"$/\1/'; }
project_name="$(pe PROJECT_NAME)"

if [ -n "${SUPERVISOR_TOKEN:-}" ] && bashio::supervisor.ping >/dev/null 2>&1; then
  bashio::log.info "Mode: Home Assistant add-on (options from the Supervisor)"
  admin_email="$(bashio::config 'admin_email')"
  app_email="$(bashio::config 'app_email')"
  if bashio::config.has_value 'public_url'; then
    url="$(bashio::config 'public_url')"
  else
    port="$(bashio::addon.port '8090/tcp')"
    url="http://homeassistant.local:${port:-8090}"
  fi
  # sidebar panel auto-login (pb_hooks/lib/halogin.js): trusted only from the ingress proxy
  export HA_AUTO_LOGIN="$(bashio::config 'auto_login')"
  export HA_USER_IDS="$(bashio::config 'ha_user_ids')"
  export HA_OWNER_FILE=/data/ha-owner   # first panel user claims it when ha_user_ids is empty
  ui_repo="$(bashio::config 'ui_repo')"; ui_version="$(bashio::config 'ui_version')"
else
  bashio::log.info "Mode: standalone (no Supervisor; options from environment variables)"
  admin_email="${ADMIN_EMAIL:-$(pe ADMIN_EMAIL)}"
  app_email="${APP_USER_EMAIL:-$(pe APP_USER_EMAIL)}"
  url="${PUBLIC_URL:-http://127.0.0.1:${PORT:-$(pe DEFAULT_PORT)}}"
  export HA_AUTO_LOGIN=false   # no Home Assistant, no ingress: never auto-login
  ui_repo="${UI_REPO:-}"; ui_version="${UI_VERSION:-}"
fi
export ADMIN_EMAIL="$admin_email"
# for the panel's setup link (pb_hooks/lib/setup.js)
export PUBLIC_URL="$url" CREDENTIALS_FILE=/data/initial-credentials.txt SETUP_SCHEME="$(pe SETUP_SCHEME)"

# Drop-in migrations/hooks (/config = /addon_configs/<slug>/ under Home Assistant; mount one at
# /config in compose) merged with the built-in ones into /data/runtime, rebuilt on every start.
export EXTRA_DIR="${EXTRA_DIR:-/config}"
# for the panel: the built-in migrations (to tell committed drop-ins apart), the repo and this build
export BUILTIN_MIGRATIONS="$app/pb_migrations" REPO_URL="$(pe REPO_URL)"
export BUILD_VERSION="$(sed -n 's/^version=//p' "$app/BUILD" 2>/dev/null)" GIT_SHA="$(sed -n 's/^commit=//p' "$app/BUILD" 2>/dev/null)"
run=/data/runtime
"$app/merge-extra.sh" "$app" "$EXTRA_DIR" "$run" | while read -r line; do bashio::log.info "$line"; done
[ -f "$EXTRA_DIR/README.txt" ] || cat > "$EXTRA_DIR/README.txt" <<'TXT'
Drop-in files for this PocketBase add-on, merged with the built-in ones on every start:
  pb_migrations/<timestamp>_<name>.js   JS migrations (applied once, at start)
  pb_hooks/<name>.pb.js                 JS hooks
Then open the add-on's sidebar panel and click "Apply migrations" (it restarts the add-on).
A file named like a built-in one is refused. Delete a file here and restart to drop a hook.
TXT

bashio::log.info "Provisioning ${project_name} (admin ${admin_email}, app login ${app_email})"
"$app/provision.sh" --dir "$data" --state-dir /data \
  --migrations-dir "$run/pb_migrations" --hooks-dir "$run/pb_hooks" \
  --url "$url" --project-name "$project_name" \
  --admin-email "$admin_email" --app-email "$app_email"

# The app UI: a GitHub release's dist.zip (ui_repo, default this repository; ui_version: latest,
# a tag, a full URL, or "bundled" = no app UI), loaded at every start into /data/ui/current and
# served at "/". The landing page (auto-login, setup, migrations) then lives at /_setup/.
# A failed download keeps the last good build; with none, the landing page stays at "/".
public="$app/pb_public"
ui_version="${ui_version:-latest}"
if [ -z "${ui_repo:-}" ] || [ "$ui_repo" = "null" ]; then
  ui_repo="$(pe REPO_URL | sed -E 's#^https?://github\.com/##; s#/+$##')"
fi
if [ "$ui_version" != bundled ] && [ -n "$ui_repo" ]; then
  case "$ui_version" in
    http*) ui_url="$ui_version" ;;
    latest) ui_url="https://github.com/$ui_repo/releases/latest/download/dist.zip" ;;
    *) ui_url="https://github.com/$ui_repo/releases/download/$ui_version/dist.zip" ;;
  esac
  rm -rf /data/ui/new /tmp/ui.zip && mkdir -p /data/ui/new
  if curl -fsSL --max-time 60 -o /tmp/ui.zip "$ui_url" && unzip -q /tmp/ui.zip -d /data/ui/new && [ -f /data/ui/new/index.html ]; then
    find /data/ui/new -type f -exec touch {} +   # now, not the build date: never a stale 304
    rm -rf /data/ui/current && mv /data/ui/new /data/ui/current
    bashio::log.info "App UI: $ui_version from $ui_repo"
  else
    rm -rf /data/ui/new
    bashio::log.warning "App UI: could not load $ui_url; keeping $([ -f /data/ui/current/index.html ] && echo the last loaded one || echo the landing page at /)"
  fi
  if [ -f /data/ui/current/index.html ]; then
    rm -rf /data/ui/current/_setup && cp -R "$app/pb_public" /data/ui/current/_setup
    public=/data/ui/current
    # for the in-app update check (pb_hooks/lib/uiupdate.js)
    export UI_DIR=/data/ui UI_REPO="$ui_repo" UI_CHANNEL="$ui_version" SETUP_SRC="$app/pb_public"
  fi
fi

bashio::log.info "Starting PocketBase on port 8090 (public URL ${url})"
exec pocketbase serve \
  --http 0.0.0.0:8090 \
  --dir "$data" \
  --migrationsDir "$run/pb_migrations" \
  --hooksDir "$run/pb_hooks" \
  --publicDir "$public" \
  --hooksWatch=false \
  --automigrate=false

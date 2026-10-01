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
else
  bashio::log.info "Mode: standalone (no Supervisor; options from environment variables)"
  admin_email="${ADMIN_EMAIL:-$(pe ADMIN_EMAIL)}"
  app_email="${APP_USER_EMAIL:-$(pe APP_USER_EMAIL)}"
  url="${PUBLIC_URL:-http://127.0.0.1:${PORT:-$(pe DEFAULT_PORT)}}"
  export HA_AUTO_LOGIN=false   # no Home Assistant, no ingress: never auto-login
fi
export ADMIN_EMAIL="$admin_email"

bashio::log.info "Provisioning ${project_name} (admin ${admin_email}, app login ${app_email})"
"$app/provision.sh" --dir "$data" --state-dir /data \
  --migrations-dir "$app/pb_migrations" --hooks-dir "$app/pb_hooks" \
  --url "$url" --project-name "$project_name" \
  --admin-email "$admin_email" --app-email "$app_email"

bashio::log.info "Starting PocketBase on port 8090 (public URL ${url})"
exec pocketbase serve \
  --http 0.0.0.0:8090 \
  --dir "$data" \
  --migrationsDir "$app/pb_migrations" \
  --hooksDir "$app/pb_hooks" \
  --publicDir "$app/pb_public" \
  --hooksWatch=false \
  --automigrate=false

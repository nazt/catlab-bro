#!/usr/bin/env bash
# Copy the one source of truth into the add-on's image context:
#   project.env, pocketbase/pb_migrations/, pb_hooks/, pb_public/, scripts/provision.sh -> addon/<ADDON_SLUG>/rootfs/opt/app/
# Run after changing any of them; `--check` only compares (CI and local-e2e.sh use it).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
pe() { sed -n "s/^$1=//p" "$here/project.env" | tail -n 1 | sed 's/^"\(.*\)"$/\1/'; }
slug="$(pe ADDON_SLUG)"
dest="$here/addon/$slug/rootfs/opt/app"
[ -d "$here/addon/$slug" ] || { echo "no add-on directory addon/$slug (ADDON_SLUG in project.env)" >&2; exit 1; }

stage="$(mktemp -d)"; trap 'rm -rf "$stage"' EXIT
cp "$here/project.env" "$here/scripts/provision.sh" "$stage/"
cp -R "$here/pocketbase/pb_migrations" "$here/pocketbase/pb_hooks" "$here/pocketbase/pb_public" "$stage/"

if [ "${1:-}" = "--check" ]; then
  if diff -r "$stage" "$dest" >/dev/null 2>&1; then echo "add-on is in sync"; exit 0; fi
  echo "add-on is OUT OF SYNC with the repo root; run scripts/sync-addon.sh" >&2
  diff -r "$stage" "$dest" >&2 || true
  exit 1
fi
rm -rf "$dest"; mkdir -p "$dest"
cp -R "$stage/." "$dest/"
echo "synced -> addon/$slug/rootfs/opt/app"

#!/usr/bin/env bash
# Give a repo made from this template its own identity, everywhere at once:
#   scripts/rename.sh "Acme Tasks" acme_tasks ["Task tracking backend for Acme"]
# Updates project.env, the add-on directory/name/slug, build labels, repository.yaml,
# compose.yaml, the README/DOCS titles, and resets the add-on CHANGELOG. Idempotent.
# The slug must be lowercase letters, digits and underscores (a Home Assistant add-on slug).
set -euo pipefail
name="${1:?usage: scripts/rename.sh \"Project Name\" project_slug [\"description\"]}"
slug="${2:?usage: scripts/rename.sh \"Project Name\" project_slug [\"description\"]}"
desc="${3:-}"
[[ "$slug" =~ ^[a-z][a-z0-9_]*$ ]] || { echo "slug must match ^[a-z][a-z0-9_]*\$ (got: $slug)" >&2; exit 1; }
[[ "$name" != *'"'* && "$name" != *'|'* && "$desc" != *'"'* && "$desc" != *'|'* ]] \
  || { echo "name/description may not contain \" or |" >&2; exit 1; }
here="$(cd "$(dirname "$0")/.." && pwd)"; cd "$here"
pe() { sed -n "s/^$1=//p" project.env | tail -n 1 | sed 's/^"\(.*\)"$/\1/'; }
old_name="$(pe PROJECT_NAME)"; old_slug="$(pe ADDON_SLUG)"; old_desc="$(pe PROJECT_DESCRIPTION)"
desc="${desc:-$old_desc}"
dash="${slug//_/-}"
# Its own host port, so two PocketBase add-ons on one Home Assistant (or two compose projects on
# one machine) never fight over 8090: 8100-8899, derived from the slug, stable across renames.
port=$((8100 + $(printf '%s' "$slug" | cksum | cut -d' ' -f1) % 800))
# sed -i that works on both BSD (macOS) and GNU sed
sub() { local f="$1"; shift; sed -E "$@" "$f" > "$f.tmp" && mv "$f.tmp" "$f"; }
changed=()

sub project.env -e "s|^PROJECT_NAME=.*|PROJECT_NAME=\"$name\"|" -e "s|^PROJECT_SLUG=.*|PROJECT_SLUG=$slug|" \
  -e "s|^ADDON_SLUG=.*|ADDON_SLUG=$slug|" -e "s|^PROJECT_DESCRIPTION=.*|PROJECT_DESCRIPTION=\"$desc\"|" \
  -e "s|^DEFAULT_PORT=.*|DEFAULT_PORT=$port|" -e "s|^SETUP_SCHEME=.*|SETUP_SCHEME=$dash|"
changed+=(project.env)

if [ "$old_slug" != "$slug" ] && [ -d "addon/$old_slug" ]; then
  if [ -d .git ] && git ls-files --error-unmatch "addon/$old_slug" >/dev/null 2>&1; then
    git mv "addon/$old_slug" "addon/$slug"
  else
    mv "addon/$old_slug" "addon/$slug"
  fi
  changed+=("addon/$old_slug -> addon/$slug")
fi
a="addon/$slug"
sub "$a/config.yaml" -e "s|^name: .*|name: $name|" -e "s|^slug: .*|slug: $slug|" -e "s|^description: .*|description: $desc|" \
  -e "s|^  8090/tcp: [0-9]+$|  8090/tcp: $port|"
sub "$a/config.yaml" -e "s|^panel_title: .*|panel_title: $name|"
sub "$a/Dockerfile" -e "s|(org.opencontainers.image.title=)\"[^\"]*\"|\1\"$name\"|" -e "s|(org.opencontainers.image.description=)\"[^\"]*\"|\1\"$desc\"|"
sub repository.yaml -e "s|^name: .*|name: $name add-ons|" -e "s|^maintainer: .*|maintainer: $name maintainers|"
sub compose.yaml -e "s|^name: .*|name: $dash|" -e "s|(context: \./addon/).*|\1$slug|" -e "s|(image: ).*:dev|\1$dash:dev|" \
  -e "s|\\\$\\{PORT:-[0-9]+\\}|\\\${PORT:-$port}|g"
# every mention of the old name in the docs (title, banner sample, add-on store entry)
esc_old="$(printf '%s' "$old_name" | sed 's/[.[\*^$/]/\\&/g')"
sub README.md -e "1s|^# .*|# $name|" -e "s|$esc_old|$name|g"
for d in docs/*.md; do [ -f "$d" ] && sub "$d" -e "s|$esc_old|$name|g" -e "s|addon/$old_slug/|addon/$slug/|g"; done
sub "$a/DOCS.md" -e "1s|^# .*|# $name|" -e "s|$esc_old|$name|g"
# the name the admin page and the example app show before they ask the backend (/api/app/about)
for f in pocketbase/pb_public/index.html ui/index.html; do sub "$f" -e "s|$esc_old|$name|g"; done
# the design system's name (DESIGN.md frontmatter + heading, and Impeccable's sidecar)
[ -f DESIGN.md ] && sub DESIGN.md -e "s|^name: $esc_old\$|name: $name|" -e "s|^# Design System: $esc_old\$|# Design System: $name|"
[ -f .impeccable/design.json ] && sub .impeccable/design.json -e "s|$esc_old|$name|g"
printf '# Changelog\n\n## 0.1.0\n\n- First version of %s, from the PocketBase backend template.\n' "$name" > "$a/CHANGELOG.md"
changed+=("$a/config.yaml" "$a/Dockerfile (labels)" "$a/DOCS.md" "$a/CHANGELOG.md" repository.yaml compose.yaml "README.md (title)" "docs/*.md (name, add-on path)" "pocketbase/pb_public/index.html + ui/index.html (name)")

scripts/sync-addon.sh >/dev/null
changed+=("$a/rootfs (synced)")
# the "open the add-on" button carries the slug: re-point the Home Assistant links
repo_url="$(sed -n 's/^url: *//p' repository.yaml)"
if [ -n "$repo_url" ]; then scripts/ha-buttons.sh "$repo_url" >/dev/null; changed+=("README.md + repository.yaml (Home Assistant links)"); fi
printf 'renamed "%s" (%s) -> "%s" (%s), host port %s\n' "$old_name" "$old_slug" "$name" "$slug" "$port"
printf '  %s\n' "${changed[@]}"
echo "Next: rewrite the README intro, replace the example collection (AGENTS.md), run scripts/local-e2e.sh."

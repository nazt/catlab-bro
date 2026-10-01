#!/usr/bin/env bash
# Pin a new PocketBase release: version + SHA-256 of the linux amd64/arm64 zips, taken from the
# release's checksums.txt. Updates the Dockerfile and CI. Then run scripts/local-e2e.sh with
# that version of the pocketbase binary.
#   scripts/bump-pocketbase.sh 0.40.5
set -euo pipefail
v="${1:?usage: scripts/bump-pocketbase.sh <version, e.g. 0.40.5>}"; v="${v#v}"
here="$(cd "$(dirname "$0")/.." && pwd)"
pe() { sed -n "s/^$1=//p" "$here/project.env" | tail -n 1 | sed 's/^"\(.*\)"$/\1/'; }
sums="$(curl -fsSL "https://github.com/pocketbase/pocketbase/releases/download/v$v/checksums.txt")"
amd="$(echo "$sums" | awk -v f="pocketbase_${v}_linux_amd64.zip" '$2==f {print $1}')"
arm="$(echo "$sums" | awk -v f="pocketbase_${v}_linux_arm64.zip" '$2==f {print $1}')"
[ ${#amd} -eq 64 ] && [ ${#arm} -eq 64 ] || { echo "checksums for v$v not found" >&2; exit 1; }
df="$here/addon/$(pe ADDON_SLUG)/Dockerfile"
sed -i.bak -E \
  -e "s/^ARG POCKETBASE_VERSION=.*/ARG POCKETBASE_VERSION=$v/" \
  -e "s/^ARG POCKETBASE_SHA256_AMD64=.*/ARG POCKETBASE_SHA256_AMD64=$amd/" \
  -e "s/^ARG POCKETBASE_SHA256_ARM64=.*/ARG POCKETBASE_SHA256_ARM64=$arm/" "$df"
rm -f "$df.bak"
ci="$here/.github/workflows/ci.yml"
[ -f "$ci" ] && { sed -i.bak -E "s/^(  POCKETBASE_VERSION: ).*/\1\"$v\"/" "$ci"; rm -f "$ci.bak"; }
echo "PocketBase pinned to v$v (amd64 ${amd:0:12}…, arm64 ${arm:0:12}…)"

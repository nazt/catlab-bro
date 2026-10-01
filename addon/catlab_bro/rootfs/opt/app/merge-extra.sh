#!/usr/bin/env bash
# Merge drop-in migrations and hooks into the directories PocketBase runs from:
#   built-in  <app>/pb_migrations, <app>/pb_hooks        (shipped in the image)
#   drop-in   <extra>/pb_migrations/*.js, <extra>/pb_hooks/*.pb.js
#             (Home Assistant: /addon_configs/<slug>/ on the host = /config in the add-on)
#   ->        <out>/pb_migrations, <out>/pb_hooks        (rebuilt on every start)
# A drop-in file with the same name as a built-in one is refused (the built-in wins), so a
# stray copy can never replace the project's own schema. PocketBase applies pending migrations
# when it starts.
#   scripts/merge-extra.sh <app-dir> <extra-dir> <out-dir>
set -euo pipefail
app="${1:?usage: merge-extra.sh <app-dir> <extra-dir> <out-dir>}"; extra="${2:?}"; out="${3:?}"
rm -rf "$out/pb_migrations" "$out/pb_hooks"
mkdir -p "$out" "$extra/pb_migrations" "$extra/pb_hooks"
cp -R "$app/pb_migrations" "$app/pb_hooks" "$out/"
added=0
for kind in pb_migrations pb_hooks; do
  pattern='*.js'; [ "$kind" = pb_hooks ] && pattern='*.pb.js'
  for f in "$extra/$kind"/$pattern; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    if [ -e "$app/$kind/$name" ]; then
      if cmp -s "$f" "$app/$kind/$name"; then
        echo "merge-extra: skipped $kind/$name: committed to the repo (now built in); the drop-in can be deleted"
      else
        echo "merge-extra: refused $kind/$name: differs from the built-in file with that name; the built-in wins" >&2
      fi
      continue
    fi
    cp "$f" "$out/$kind/$name"; added=$((added + 1))
    echo "merge-extra: + $kind/$name"
  done
done
echo "merge-extra: $added drop-in file(s) from $extra"

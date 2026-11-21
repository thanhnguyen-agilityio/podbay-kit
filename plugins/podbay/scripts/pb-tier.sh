#!/bin/bash
# Risk tier of a change, from its file paths. The one place the tier paths live.
# Usage: pb-tier.sh <base> <head> [checkout]   (paths from git diff --name-only <base>...<head>)
#        pb-tier.sh --files <file> ...         (paths given directly; for tests)
# Prints:  tier=light|full   then one "sensitive: <path>" line per sensitive path.
#   light: every path is docs or site text (docs/, site/, *.md). One short review round; pb-ci optional.
#   full:  anything else. Full isolated review and a pb-ci pass on the head.
#   sensitive (inside full): auth, network, saved state, migrations, service, UI kit, dependencies, build script.
#            A person's review note is also needed before merge (label pb::human-reviewed).
# Exit 0, or 2 on bad usage / git error.
set -u
if [ "${1:-}" = "--files" ]; then shift; files="$(printf '%s\n' "$@")"
else
  [ $# -ge 2 ] || { echo "usage: pb-tier.sh <base> <head> [checkout] | --files <file> ..." >&2; exit 2; }
  files="$(git -C "${3:-.}" diff --name-only "$1...$2" 2>/dev/null)" || { echo "pb-tier: git diff failed for $1...$2" >&2; exit 2; }
fi
light=1; sens=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in docs/*|site/*|*.md) ;; *) light=0 ;; esac
  case "$f" in
    src/net/*|*/secure.rs|secure.rs|*/state.rs|state.rs|*/ops.rs|*/service.rs|src/ui/kit*|*auth*|*migrat*|Cargo.toml|Cargo.lock|build.rs)
      sens="$sens
sensitive: $f" ;;
  esac
done <<< "$files"
[ -n "$files" ] || light=0
if [ "$light" = 1 ]; then echo "tier=light"; else echo "tier=full"; fi
[ -z "$sens" ] || printf '%s\n' "${sens#
}"
exit 0

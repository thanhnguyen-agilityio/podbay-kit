#!/bin/bash
# Risk tier of a change, from its file paths. The one place the tier paths live.
# Usage: pb-tier.sh <base> <head> [checkout]   (paths from git diff --name-only <base>...<head>)
#        pb-tier.sh --files <file> ...         (paths given directly; for tests)
# Prints:  tier=light|full   then one "sensitive: <path>" line per sensitive path.
#   light: every path is docs or site text (docs/, site/, *.md). One short review round; pb-ci optional.
#   full:  anything else. Full isolated review and a pb-ci pass on the head.
#   sensitive (any tier, even light): auth, network, saved state, migrations, service, UI kit, dependencies, build script.
#            A person's review note is also needed before merge (label human-reviewed).
# Exit 0, or 2 on bad usage / git error.
set -u
# Paths are read NUL-separated with renames split into delete + add, so a moved or
# non-ASCII sensitive path is still seen under its old and its new name.
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
if [ "${1:-}" = "--files" ]; then shift; [ $# -eq 0 ] || printf '%s\0' "$@" > "$tmp"
else
  [ $# -ge 2 ] || { echo "usage: pb-tier.sh <base> <head> [checkout] | --files <file> ..." >&2; exit 2; }
  git -C "${3:-.}" diff -z --name-only --no-renames "$1...$2" > "$tmp" 2>/dev/null || { echo "pb-tier: git diff failed for $1...$2" >&2; exit 2; }
fi
light=1; sens=""; n=0
while IFS= read -r -d '' f; do
  [ -n "$f" ] || continue
  n=$((n + 1))
  case "$f" in docs/*|site/*|*.md) ;; *) light=0 ;; esac
  lf="$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]')"
  case "$lf" in
    src/net/*|*/src/net/*|secure.rs|*/secure.rs|state.rs|*/state.rs|*/ops.rs|*/service.rs|src/ui/kit*|*/src/ui/kit*|*auth*|*migrat*|cargo.toml|*/cargo.toml|cargo.lock|*/cargo.lock|build.rs|*/build.rs)
      sens="$sens
sensitive: $f" ;;
  esac
done < "$tmp"
[ "$n" -gt 0 ] || light=0
if [ "$light" = 1 ]; then echo "tier=light"; else echo "tier=full"; fi
[ -z "$sens" ] || printf '%s\n' "${sens#
}"
exit 0

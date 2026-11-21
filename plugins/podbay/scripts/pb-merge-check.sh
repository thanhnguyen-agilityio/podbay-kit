#!/bin/bash
# Check an MR before the orchestrator merges it: the reviewed commit, the pb-ci commit and the MR head are the same.
# Usage: pb-merge-check.sh <mr iid> -R <group/project> [--checkout <path>]
# Passes when:
#   - the MR is open and its target is not main, master or release/* (a person merges those),
#   - an isolated review covers the head: a .podbay/review/*.md file whose Reviewer line ends "head <sha7>",
#     or an MR note headed "Isolated review, round <k>, commit <sha7>",
#   - .podbay/ci/<sha12>.log has "PBCI-HEAD sha=<head>" and a summary with no "=fail",
#   - a sensitive change (pb-tier.sh) carries the label pb::human-reviewed.
# Then it prints the merge command, pinned to the head: glab mr merge <iid> -R <repo> --sha <head>.
# Exit 0 pass, 1 a check failed, 2 bad usage or unreadable MR.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
iid=""; repo=""; co="."
while [ $# -gt 0 ]; do
  case "$1" in
    -R) repo="${2:-}"; shift 2 ;;
    --checkout) co="${2:-}"; shift 2 ;;
    *) [ -z "$iid" ] && iid="${1#!}" || { echo "pb-merge-check: unexpected $1" >&2; exit 2; }; shift ;;
  esac
done
case "$iid" in ''|*[!0-9]*) echo "usage: pb-merge-check.sh <mr iid> -R <group/project> [--checkout <path>]" >&2; exit 2 ;; esac
[ -n "$repo" ] || { echo "pb-merge-check: give -R <group/project>" >&2; exit 2; }
co="$(cd "$co" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || { echo "pb-merge-check: --checkout is not a git checkout" >&2; exit 2; }

json="$(glab mr view "$iid" -R "$repo" --output json 2>/dev/null)" || { echo "pb-merge-check: cannot read MR !$iid" >&2; exit 2; }
read -r state sha target labels <<< "$(printf '%s' "$json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("state", ""), d.get("sha", ""), d.get("target_branch", ""), ",".join(d.get("labels") or []) or "-")')"
case "$sha" in [0-9a-f]*) ;; *) echo "pb-merge-check: MR !$iid has no head sha" >&2; exit 2 ;; esac
s7="${sha:0:7}"; s12="${sha:0:12}"
fails=0
ok()   { echo "ok    $1"; }
fail() { echo "FAIL  $1"; fails=$((fails + 1)); }

[ "$state" = opened ] && ok "MR !$iid is open" || fail "MR !$iid is $state, not open"
case "$target" in
  main|master|release/*) fail "target $target: a person merges into main, master and release/* (contract, Gate 2)" ;;
  "") fail "no target branch" ;;
  *) ok "target $target is an integration branch" ;;
esac

if grep -lE "head ${s7}[0-9a-f]*[[:space:]]*\"?\$" "$co"/.podbay/review/*.md >/dev/null 2>&1; then
  ok "isolated review covers head $s7 (.podbay/review)"
else
  pid="$(glab api "projects/$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$repo")" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))' 2>/dev/null)"
  if [ -n "$pid" ] && glab api "projects/$pid/merge_requests/$iid/notes?per_page=100" 2>/dev/null | grep -qE "Isolated review, round [0-9]+, commit ${s7}"; then
    ok "isolated review covers head $s7 (MR note)"
  else
    fail "no isolated review of head $s7: run pb-review on the current head"
  fi
fi

log="$co/.podbay/ci/$s12.log"
if [ ! -f "$log" ]; then fail "no pb-ci log for head ($log): run pb-ci on the head"
elif ! grep -q "^PBCI-HEAD sha=$sha" "$log"; then fail "pb-ci log $s12 was built from another commit"
elif ! grep -q "^pb-ci $s12 " "$log"; then fail "pb-ci log $s12 has no summary line (run not finished)"
elif grep "^pb-ci $s12 " "$log" | tail -1 | grep -q "=fail"; then fail "pb-ci failed on head: $(grep "^pb-ci $s12 " "$log" | tail -1 | cut -c1-160)"
else ok "pb-ci passed on head $s12"; fi

if git -C "$co" cat-file -e "$sha" 2>/dev/null && git -C "$co" rev-parse -q --verify "origin/$target" >/dev/null; then
  tier="$("$HERE/pb-tier.sh" "origin/$target" "$sha" "$co")"
  echo "      $(printf '%s' "$tier" | head -1)"
  if printf '%s' "$tier" | grep -q '^sensitive:'; then
    case ",$labels," in *,pb::human-reviewed,*) ok "sensitive change has pb::human-reviewed" ;;
      *) fail "sensitive change ($(printf '%s' "$tier" | grep -c '^sensitive:') paths): needs a person's review note and the label pb::human-reviewed" ;; esac
  fi
else
  fail "head $s7 or origin/$target is not in the checkout: git fetch origin, then rerun"
fi

if [ "$fails" -eq 0 ]; then
  echo "merge-check: OK. Merge with: glab mr merge $iid -R $repo --sha $sha"
  exit 0
fi
echo "merge-check: $fails check(s) failed, do not merge"
exit 1

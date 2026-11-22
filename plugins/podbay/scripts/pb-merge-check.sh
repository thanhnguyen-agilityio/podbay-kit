#!/bin/bash
# Check an MR before the orchestrator merges it: the reviewed commit, the pb-ci commit and the MR head are the same.
# Usage: pb-merge-check.sh <mr iid> -R <group/project> [--checkout <path>]
# Passes when:
#   - the MR is open and its target is not main, master or release/* (a person merges those),
#   - an isolated review covers the head: a .podbay/review/*.md file whose "Reviewer:" line ends "head <sha prefix>",
#     or an MR note headed "Isolated review, round <k>, commit <sha7>",
#   - .podbay/ci/<sha12>.log has "PBCI-HEAD sha=<head>" and a summary with build=pass, clippy=pass, test=pass and no "=fail",
#   - a sensitive change (pb-tier.sh) carries the label pb::human-reviewed (only a person adds it; contract).
# It checks commits, not findings: an open blocker in a review on the head still passes this check.
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
# Fields are joined with the unit separator (0x1f), so an empty field cannot shift the others.
US="$(printf '\037')"
IFS="$US" read -r state sha target labels <<< "$(printf '%s' "$json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("\x1f".join([d.get("state") or "", d.get("sha") or "", d.get("target_branch") or "", ",".join(d.get("labels") or [])]))')"
printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$' || { echo "pb-merge-check: MR !$iid has no head sha (got: ${sha:-none})" >&2; exit 2; }
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

# covers <sha prefix ...>: true when one of the given short shas (7 to 40 hex) is a prefix of the head.
covers() { local x; for x in "$@"; do case "$sha" in "$x"*) return 0 ;; esac; done; return 1; }
# The Reviewer line may carry Markdown (**Reviewer:**, a list number) and end in a quote, dot or star.
rev_shas="$(grep -hE '^[^A-Za-z]*Reviewer[^A-Za-z].*head [0-9a-f]{7,40}[^0-9A-Za-z]*$' "$co"/.podbay/review/*.md 2>/dev/null | grep -oE 'head [0-9a-f]{7,40}[^0-9A-Za-z]*$' | grep -oE '[0-9a-f]{7,40}')"
# shellcheck disable=SC2086
if [ -n "$rev_shas" ] && covers $rev_shas; then
  ok "isolated review covers head $s7 (.podbay/review)"
else
  pid="$(glab api "projects/$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$repo")" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))' 2>/dev/null)"
  note_shas="$([ -n "$pid" ] && glab api "projects/$pid/merge_requests/$iid/notes?per_page=100" 2>/dev/null | grep -oE 'Isolated review, round [0-9]+, commit [0-9a-f]{7,40}' | awk '{print $NF}')"
  # shellcheck disable=SC2086
  if [ -n "$note_shas" ] && covers $note_shas; then
    ok "isolated review covers head $s7 (MR note)"
  elif [ -z "$pid" ]; then
    fail "no isolated review of head $s7 in .podbay/review, and the MR notes could not be read (glab api failed)"
  else
    fail "no isolated review of head $s7: run pb-review on the current head (after a clean rebase, post the carry-over note; contract)"
  fi
fi

log="$co/.podbay/ci/$s12.log"
if [ ! -f "$log" ]; then fail "no pb-ci log for head ($log): run pb-ci on the head"
elif ! grep -q "^PBCI-HEAD sha=$sha" "$log"; then fail "pb-ci log $s12 was built from another commit"
elif ! grep -q "^pb-ci $s12 " "$log"; then fail "pb-ci log $s12 has no summary line (run not finished)"
elif grep "^pb-ci $s12 " "$log" | tail -1 | grep -q "=fail"; then fail "pb-ci failed on head: $(grep "^pb-ci $s12 " "$log" | tail -1 | cut -c1-160)"
elif ! grep "^pb-ci $s12 " "$log" | tail -1 | grep -q " build=pass" || ! grep "^pb-ci $s12 " "$log" | tail -1 | grep -q " clippy=pass" || ! grep "^pb-ci $s12 " "$log" | tail -1 | grep -q " test=pass"; then
  fail "pb-ci summary for $s12 lacks build=pass, clippy=pass and test=pass (steps missing): run pb-ci again"
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

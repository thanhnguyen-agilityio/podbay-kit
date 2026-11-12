#!/bin/bash
# Feeds sample hook payloads to pb-guard.sh and asserts allow (exit 0) or block (exit 2).
# Usage: test-pb-guard.sh [scratch-dir]   (default: a fresh mktemp dir, removed afterwards)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GUARD="$HERE/pb-guard.sh"
if [ -n "${1:-}" ]; then D="$1"; mkdir -p "$D"; else D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT; fi
# A throwaway repo stands in for the one repo allowed to push to main (env PB_KIT_REPO).
mkdir -p "$D/kitrepo/sub" && KITREPO="$(cd "$D/kitrepo" && pwd -P)"
export PB_KIT_REPO="$KITREPO"
UNSET_KIT=0

printf '## What\nFix the copy label.\n' > "$D/clean.md"
printf 'token: "%s"\n' "glpat-""abcdefghijklmnopqrstuv" > "$D/secret.md"

pass=0; fail=0
# check <allow|block> <label> <command> [tool]
check() {
  local want="$1" label="$2" cmd="$3" tool="${4:-Bash}" payload rc err
  payload="$(CMD="$cmd" TOOL="$tool" python3 -c '
import json, os
ti = {"command": os.environ["CMD"]} if os.environ["TOOL"] == "Bash" else {"file_path": "/etc/hosts"}
print(json.dumps({"tool_name": os.environ["TOOL"], "tool_input": ti, "cwd": "/tmp"}))')"
  if [ "$UNSET_KIT" = 1 ]; then err="$(printf '%s' "$payload" | env -u PB_KIT_REPO "$GUARD" 2>&1 >/dev/null)"; rc=$?
  else err="$(printf '%s' "$payload" | "$GUARD" 2>&1 >/dev/null)"; rc=$?; fi
  local got=allow; [ $rc -eq 2 ] && got=block
  [ $rc -ne 0 ] && [ $rc -ne 2 ] && got="exit$rc"
  if [ "$got" = "$want" ]; then pass=$((pass+1)); printf 'ok    %-5s %s\n' "$want" "$label"
  else fail=$((fail+1)); printf 'FAIL  want %s got %s: %s\n' "$want" "$got" "$label"; fi
  if [ "$got" = block ] && [ -n "$err" ]; then printf '        -> %s\n' "$(printf '%s' "$err" | head -c 160 | head -1)"; fi
}

check allow "cargo test --locked" "cargo test --locked"
check block "cargo fmt" "cargo fmt"
check block "cargo fmt in a chain" "cd x && cargo fmt --all"
check block "rustfmt" "rustfmt src/main.rs"
check allow "cargo clippy" "cargo clippy --all-targets -- -D warnings"
check allow "push feature branch" "git push -u origin fix/issue-3-copy-label"
check block "push origin main" "git push origin main"
check block "push HEAD:main" "git push origin HEAD:main"
check block "push -u origin main" "git push -u origin main"
check block "push master" "git push origin master"
check block "push --force" "git push --force origin fix/x"
check block "push -f" "git push -f origin fix/x"
check block "push --force-with-lease" "git push --force-with-lease origin fix/x"
check block "push +refspec" "git push origin +fix/x"
check block "compound push to main" "git status && git push origin main"
check block "kit -C then real push to main" "git -C $KITREPO push origin HEAD:main && git push origin HEAD:main"
check allow "kit repo push via -C" "git -C $KITREPO push origin HEAD:main"
check allow "kit repo push via -C sub/.." "git -C $KITREPO/sub/.. push origin HEAD:main"
check allow "kit repo push via cd" "cd $KITREPO && git push origin HEAD:main"
check block "kit -C but force" "git -C $KITREPO push --force origin HEAD:main"
UNSET_KIT=1
check block "PB_KIT_REPO unset: -C repo push to main" "git -C $KITREPO push origin HEAD:main"
check block "PB_KIT_REPO unset: cd then push to main" "cd $KITREPO && git push origin HEAD:main"
UNSET_KIT=0
check block "-C other repo main" "git -C /tmp push origin HEAD:main"
check block "glab mr merge" "glab mr merge 4 -R group/project"
check block "glab mr approve" "glab mr approve 4"
check block "glab api PUT merge" "glab api -X PUT projects/123/merge_requests/4/merge"
check block "glab api POST approve" "glab api -X POST projects/123/merge_requests/4/approve"
check allow "glab api GET" "glab api projects/123/merge_requests/4"
check allow "mr create, clean file" "glab mr create --title 'Fix label' --description-file $D/clean.md --remove-source-branch --squash-before-merge"
check block "mr create, secret file" "glab mr create --title 'Fix label' --description-file $D/secret.md"
check block "mr create, secret file (=)" "glab mr create --description-file=$D/secret.md"
check block "mr create, missing file" "glab mr create --title x --description-file $D/nope.md"
check block "mr create, variable path" "glab mr create --title x --description-file \$F"
check block "api -F @secret file" "glab api -X POST projects/1/uploads -F file=@$D/secret.md"
check allow "api -F @clean file" "glab api -X POST projects/1/uploads -F file=@$D/clean.md"
check block "inline secret in -m" "glab issue note 3 -m 'password=hunter2hunter2'"
check allow "issue note -m fixed" "glab issue note 3 -m \"fixed\""
check allow "issue view" "glab issue view 3 -R group/project --comments"
check allow "Read tool payload" "ignored" Read

printf '\211PNG\r\n\032\n\000\000' > "$D/shot.png"
git init -q -b main "$D/onmain" && git init -q -b fix/x "$D/onbranch"
check allow "upload png screenshot" "glab api -X POST projects/1/uploads -F file=@$D/shot.png"
check block "bare push while on main" "git -C $D/onmain push"
check block "push origin HEAD while on main" "cd $D/onmain && git push origin HEAD"
check allow "bare push on a branch" "git -C $D/onbranch push"
check allow "push -u origin HEAD on a branch" "git -C $D/onbranch push -u origin HEAD"

# private references
printf 'Show zero in the tile.\n<!-- pb:worklog -->\n```rust\nlet x: f32 = 1.0;\n```\n' > "$D/f13-issue.md"
printf 'Review artifact finding #15\n' > "$D/pr1.md"
printf 'fn f13_uncommitted_lines_tile_shows_zero() {\n' > "$D/pr2.md"
printf -- '- f13.Q1 Value for zero → "0" (Sam)\n' > "$D/pr3.md"
check allow "issue create, f13 in path only" "glab issue create --title x --description-file $D/f13-issue.md"
check block "review artifact finding #" "glab issue create --title x --description-file $D/pr1.md"
check block "f13_ test name" "glab issue create --title x --description-file $D/pr2.md"
check block "f13.Q1 bullet" "glab issue create --title x --description-file $D/pr3.md"
check block "verify:: label in command" "glab issue update 3 -R group/project --label 'verify::L1'"
check allow "plain labels in command" "glab issue update 3 -R group/project --label 'priority::low,type::bug'"

PRC="$HERE/private-ref-check.sh"
# direct <want-rc> <label> <file>
direct() {
  "$PRC" "$3" >/dev/null 2>&1; local rc=$?
  if [ "$rc" = "$1" ]; then pass=$((pass+1)); printf 'ok    rc %s %s\n' "$1" "$2"
  else fail=$((fail+1)); printf 'FAIL  want rc %s got %s: %s\n' "$1" "$rc" "$2"; fi
}
direct 0 "private-ref-check clean file" "$D/clean.md"
direct 1 "private-ref-check matching file" "$D/pr3.md"
direct 2 "private-ref-check missing file" "$D/nope.md"
printf -- '- t2.Q1 Keep the card order (Sam)\n' > "$D/pr4.md"
printf 'Covers F-SES-04.\n' > "$D/pr5.md"
printf 'Uses a 2x2 grid, size 12.\n' > "$D/clean2.md"
direct 1 "private-ref-check ticket id" "$D/pr4.md"
direct 1 "private-ref-check feature id" "$D/pr5.md"
direct 0 "private-ref-check no false hit" "$D/clean2.md"

echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]

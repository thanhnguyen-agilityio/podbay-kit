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

# A fake glab first on PATH answers `glab mr view <n> --output json` with a fixed target branch.
mkdir -p "$D/bin"
cat > "$D/bin/glab" <<'FAKE'
#!/bin/bash
[ "$1 $2" = "mr view" ] || exit 1
case "${3#!}" in
  4) t=main ;; 5) t=release/2026.11.13 ;; 6) t=feat/switch-account ;; 8) t=master ;;
  9) echo '{"iid":9}'; exit 0 ;; *) echo "not found" >&2; exit 1 ;;
esac
printf '{"iid":%s,"target_branch":"%s"}\n' "${3#!}" "$t"
FAKE
chmod +x "$D/bin/glab"
export PATH="$D/bin:$PATH"

pass=0; fail=0
# Free disk seen by the guard; per-case overrides below. Keeps the suite independent of this machine's disk.
export PB_FREE_GB_OVERRIDE=100
MSG_RE=""   # when set, a block must print a message matching this regex
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
  if [ "$got" = block ] && [ -n "$MSG_RE" ] && ! printf '%s' "$err" | grep -Eq -- "$MSG_RE"; then got="block-without-/$MSG_RE/"; fi
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
check block "merge into release/*" "glab mr merge 5 -R group/project"
check block "merge into master" "glab mr merge 8"
check allow "merge into an epic branch" "glab mr merge 6 -R group/project --squash"
check allow "merge !6 into an epic branch" "glab mr merge !6 --yes"
check block "merge, target lookup fails" "glab mr merge 7"
check block "merge, no target in answer" "glab mr merge 9"
check block "merge without an MR number" "glab mr merge -R group/project"
check block "approve stays blocked on epic MR" "glab mr approve 6"
check block "allowed merge chained with a main merge" "glab mr merge 6 && glab mr merge 4"
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

# disk floor (default 10 GB, env PB_DISK_FLOOR_GB; PB_FREE_GB_OVERRIDE is for tests)
MSG_RE="10 GB"
PB_FREE_GB_OVERRIDE=3 check block "low disk: cargo test" "cargo test --locked"
PB_FREE_GB_OVERRIDE=3 check block "low disk: cargo build in a chain" "cd /tmp && CARGO_TARGET_DIR=/tmp/t cargo build --locked"
PB_FREE_GB_OVERRIDE=3 check block "low disk: cargo clippy" "cargo clippy --all-targets --locked -- -D warnings"
PB_FREE_GB_OVERRIDE=3 check block "low disk: cargo run" "cargo run --locked"
PB_FREE_GB_OVERRIDE=3 check block "low disk: pb-ci" "bash /x/skills/pb-ci/pb-ci.sh /y/podbay"
MSG_RE="2 GB"
PB_FREE_GB_OVERRIDE=1 PB_DISK_FLOOR_GB=2 check block "low disk: custom floor named" "cargo test --locked"
MSG_RE=""
PB_FREE_GB_OVERRIDE=3 PB_DISK_FLOOR_GB=2 check allow "custom floor under free space" "cargo test --locked"
PB_FREE_GB_OVERRIDE=40 check allow "40 GB free: cargo test" "cargo test --locked"
PB_FREE_GB_OVERRIDE=3 check allow "low disk: cargo --version" "cargo --version"
PB_FREE_GB_OVERRIDE=3 check allow "low disk: git status" "git status"
PB_FREE_GB_OVERRIDE=3 check allow "low disk: grep for cargo test" "grep -n 'cargo test' README.md"
PB_FREE_GB_OVERRIDE= PB_DISK_FLOOR_GB=100000 check block "real df reading under a huge floor" "cargo test --locked"
PB_FREE_GB_OVERRIDE=3 check block "low disk: env prefix" "env RUST_LOG=debug cargo test --locked"
PB_FREE_GB_OVERRIDE=3 check block "low disk: time prefix" "time cargo build --locked"
PB_FREE_GB_OVERRIDE=3 check block "low disk: cargo check" "cargo check --locked"
PB_FREE_GB_OVERRIDE=3 check allow "low disk: commit message mentions cargo build" "git commit -m \"Make cargo build faster\""
PB_FREE_GB_OVERRIDE=3 check allow "low disk: echo mentions cargo test" "echo please run cargo test"
# Bad values never switch the other rules off.
PB_DISK_FLOOR_GB=7.5 check block "floor 7.5 does not disable the main-push rule" "cargo build; git push origin main"
PB_DISK_FLOOR_GB=10GB check block "floor 10GB does not disable the force-push rule" "cargo build; git push --force origin feat"
PB_FREE_GB_OVERRIDE=abc check block "bad override does not disable the main-push rule" "cargo build; git push origin main"
PB_FREE_GB_OVERRIDE=3 PB_DISK_FLOOR_GB=ten check block "bad floor falls back to 10 GB" "cargo test --locked"
PB_FREE_GB_OVERRIDE=40 PB_DISK_FLOOR_GB=7.5 check allow "bad floor, 40 GB free" "cargo test --locked"
PB_DISK_FLOOR_GB=08 check block "floor 08 (octal trap) keeps the main-push rule" "cargo build; git push origin main"
PB_DISK_FLOOR_GB=09 check block "floor 09 keeps the main-push rule" "cargo build; git push origin main"
PB_FREE_GB_OVERRIDE=08 check block "override 08 keeps the main-push rule" "cargo build; git push origin main"
PB_DISK_FLOOR_GB=99999999999999999999 check block "huge floor keeps the main-push rule" "cargo build; git push origin main"
PB_FREE_GB_OVERRIDE=9 PB_DISK_FLOOR_GB=010 check block "floor 010 means 10, not 8" "cargo test --locked"
PB_FREE_GB_OVERRIDE=3 check block "low disk: quoted prefix value" "RUSTFLAGS=\"-D warnings\" cargo build --locked"
PB_FREE_GB_OVERRIDE=3 check block "low disk: flag before subcommand" "cargo -q build"
PB_FREE_GB_OVERRIDE=3 check block "low disk: --locked before subcommand" "cargo --locked test"
PB_FREE_GB_OVERRIDE=3 check block "low disk: path to cargo" "~/.cargo/bin/cargo test"
PB_FREE_GB_OVERRIDE=3 check block "low disk: nice -n 10" "nice -n 10 cargo test"

# variables set earlier in the same command
check allow "var path: mr create" "S=$D; glab mr create --title x --description-file \"\$S/clean.md\""
check allow "\${var} path: api -F @file" "S=$D; glab api -X POST projects/1/merge_requests/5/notes -F body=@\"\${S}/clean.md\""
check allow "export var path" "export S=$D && glab issue note 3 -R group/project -F body=@\$S/clean.md"
check allow "var built from \$HOME-free var" "A=$D; B=\$A/clean.md; glab mr create --title x --description-file \"\$B\""
check block "var path, secret file" "S=$D; glab mr create --title x --description-file \"\$S/secret.md\""
check block "var path, private reference" "S=$D; glab issue create --title x --description-file \"\$S/pr3.md\""
MSG_RE="S=/"
check block "var from command substitution: fix named" "S=\$(mktemp -d); glab mr create --title x --description-file \"\$S/clean.md\""
MSG_RE=""
check block "var set after use" "glab mr create --title x --description-file \"\$S/clean.md\"; S=$D"
# The guard must never scan a different file than the one bash passes: $D/c/n.md is clean, $D/b/n.md has a secret.
mkdir -p "$D/c" "$D/b"; cp "$D/clean.md" "$D/c/n.md"; cp "$D/secret.md" "$D/b/n.md"
G="glab mr create --title x --description-file \"\$S/n.md\""
check block "conditional reassignment &&" "S=$D/b; false && S=$D/c; $G"
check block "conditional reassignment ||" "S=$D/b; true || S=$D/c; $G"
check block "assignment in a pipe" "S=$D/b; S=$D/c | cat; $G"
check block "assignment in the background" "S=$D/b; S=$D/c & $G"
check block "assignment in a subshell" "S=$D/b; (S=$D/c); $G"
check block "assignment line in a heredoc" "cat > /tmp/pbg-x <<EOF
S=$D/c
EOF
$G"
check block "append +=" "S=$D/c; S+=/../b; $G"
check block "second assignment with a prefix" "S=$D/c; S=$D/b X=1; $G"
check block "declare" "S=$D/c; declare S=$D/b; $G"
check block "read" "S=$D/c; read S < /dev/null; $G"
check block "printf -v" "S=$D/c; printf -v S %s $D/b; $G"
check block "for loop variable" "S=$D/c; for S in $D/b; do $G; done"
check block "unset" "S=$D/c; unset S; $G"
check block "single-quoted path is literal" "S=$D/c; glab mr create --title x --description-file '\$S/n.md'"
check block "tab in the value" "S=\"$D/c	\"; $G"
check block "HOME reassigned, ~ path" "HOME=$D/b; glab mr create --title x --description-file ~/n.md"
# Only a strict prefix of plain assignments at the very start counts (round-2 cases). Path form: "${S}n.md".
H="glab mr create --title x --description-file \"\${S}n.md\""
cp "$D/secret.md" "$D/n.md"
check block "assignment text inside quotes" "echo \"x;S=$D/c/;\"; $H"
check block "assignment after a comment" "true #;S=$D/c/
$H"
check block "assignment in a group piped to cat" "{ :; S=$D/c/; } | cat; $H"
check block "assignment in a multi-line subshell" "(
S=$D/c/
)
$H"
check block "assignment in an uncalled function" "f() {
S=$D/c/
}
$H"
check block "assignment in an if that is false" "if false; then
S=$D/c/
fi
$H"
check block "assignment after && on the next line" "false &&
S=$D/c/
$H"
check block "assignment inside a multi-line quote" "echo '
S=$D/c/
'
$H"
check block "eval after the assignment" "S=$D/c/; eval \$'\\\\x53=$D/'; $H"
check block "bash-set name \$_" "_=$D/c; true $D/b; glab mr create --title x --description-file \"\$_/n.md\""
check block "bash-set name \$REPLY" "REPLY=$D/c; read < /dev/null; glab mr create --title x --description-file \"\$REPLY/n.md\""
check block "value is a quoted tilde" "S=\"~\"; glab mr create --title x --description-file \"\$S/n.md\""
check block "value is a single-quoted \$HOME" "S='\$HOME/x'; glab mr create --title x --description-file \"\$S/n.md\""
check block "read HOME, then a ~ path" "read HOME < /dev/null; glab mr create --title x --description-file ~/n.md"
check block "unset HOME, then a ~ path" "unset HOME; glab mr create --title x --description-file ~/n.md"
check block "value with a space, unquoted use" "S=\"$D/c /x\"; glab mr create --title x --description-file \$S/n.md"
check allow "one plain assignment, then use" "S=$D/c; $G"
check allow "assignment then && use" "S=$D/c && $G"
# Variables never widen the push-to-main exception: cd and -C take literal paths only.
check block "-C via a variable, push to main" "R=$KITREPO; git -C \"\$R\" push origin HEAD:main"
check block "-C via a reassigned variable, push to main" "R=/tmp; false && R=$KITREPO; git -C \"\$R\" push origin main"
check block "cd via a variable, push to main" "R=$KITREPO; cd \"\$R\" && git push origin HEAD:main"

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

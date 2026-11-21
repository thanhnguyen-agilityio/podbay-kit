#!/bin/bash
# Checks rules that live in skill and reference text (no hook can enforce them).
# Usage: test-kit-text.sh   (prints ok/FAIL per case and a passed/failed line; exit 1 on any failure)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$HERE/.." && pwd -P)"
PRC="$HERE/private-ref-check.sh"
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; }
# has <label> <file> <ERE>: the file must match
has()   { if grep -Eq -- "$3" "$ROOT/$2"; then ok "$1"; else bad "$1 ($2 lacks /$3/)"; fi; }
# lacks <label> <file> <ERE>: the file must not match
lacks() { if grep -Eq -- "$3" "$ROOT/$2"; then bad "$1 ($2 has /$3/: $(grep -En -- "$3" "$ROOT/$2" | head -1 | cut -c1-80))"; else ok "$1"; fi; }
# step <label> <file> <step-number regex> <ERE>: the numbered step's line must match
step()  { if grep -E "^$3\. " "$ROOT/$2" | grep -Eq -- "$4"; then ok "$1"; else bad "$1 (step $3 of $2 lacks /$4/)"; fi; }

# Item 4: review text is checked for private references before it is posted.
cat > "$D/review-raw.md" <<'EOF'
### Isolated review, round 1, commit abc1234
- should fix: finding #2 from .podbay/triage/2026-11-19.md is not met: the tile shows "-" for zero.
EOF
cat > "$D/review-plain.md" <<'EOF'
### Isolated review, round 1, commit abc1234
- should fix: src/ui/overview.rs:120 shows "-" for zero uncommitted lines; the issue expects "0".
EOF
"$PRC" "$D/review-raw.md" >/dev/null 2>&1; [ $? -eq 1 ] && ok "sample review with a finding number and notes path is caught" || bad "sample review with a finding number and notes path is caught"
"$PRC" "$D/review-plain.md" >/dev/null 2>&1; [ $? -eq 0 ] && ok "plain sample review passes" || bad "plain sample review passes"
has   "pb-review drafts the comment and runs private-ref-check" skills/pb-review/SKILL.md 'private-ref-check\.sh'
has   "pb-review writes the comment from the diff, not the notes" skills/pb-review/SKILL.md 'from the diff'
step  "pb-mr checks each file right before it posts" skills/pb-mr/SKILL.md 10 'private-ref-check\.sh'
has   "reviewer names findings by place, never by number or id" reference/reviewer-prompt.md 'never by a number or id'
lacks "review comment template has no finding-id field" reference/mr-checklist.md '<finding id>|finding #<'

# Item 7: the reviewer takes its target dir from the caller.
lacks "reviewer prompt has no hard-coded target dir" reference/reviewer-prompt.md 'cargo-target/podbay|\$HOME/\.cache|/Users/'
has   "reviewer prompt takes <target dir> as an input" reference/reviewer-prompt.md '^- `<target dir>`'
has   "reviewer prompt sets CARGO_INCREMENTAL=0" reference/reviewer-prompt.md 'CARGO_INCREMENTAL=0'
has   "pb-review passes <target dir>" skills/pb-review/SKILL.md '<target dir>'
has   "pb-auto-issues passes <target dir>" skills/pb-auto-issues/SKILL.md '<target dir>'

echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]

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

# Artifact links: only published artifact pages, shared with anyone who has the link.
has   "contract allows claude.ai/artifact links and says to share them first" reference/contract.md 'claude\.ai/artifact/<id>.*Anyone with the link'

# Item 7: the reviewer takes its target dir from the caller.
lacks "reviewer prompt has no hard-coded target dir" reference/reviewer-prompt.md 'cargo-target/podbay|\$HOME/\.cache|~/\.cache|/Users/|/home/'
has   "reviewer prompt takes <target dir> as an input" reference/reviewer-prompt.md '^- `<target dir>`'
has   "reviewer prompt sets CARGO_INCREMENTAL=0" reference/reviewer-prompt.md 'CARGO_INCREMENTAL=0'
has   "pb-review passes <target dir>" skills/pb-review/SKILL.md '<target dir>'
has   "pb-fix batch mode passes <target dir>" skills/pb-fix/references/batch.md '<target dir>'

# Grill first (0.7.1): every task starts with grill-me before code.
has   "contract has the grill-first rule" reference/contract.md '^## Grill first'
has   "contract allows an explicit skip with a reason" reference/contract.md 'skip grill: <reason>'
step  "pb-triage grills first" skills/pb-triage/SKILL.md 1b 'Grill first'
step  "pb-fix grills first and refuses to code without answers" skills/pb-fix/SKILL.md 1b 'Do not start step 3 without those answers'
has   "grill-me is back in tools" ../tools/skills/grill-me/SKILL.md 'tools:grilling'
has   "wayfinder keeps its source and license" ../tools/skills/wayfinder/SKILL.md 'mattpocock/skills.*MIT'

# Kit clean-up (0.7.0): one skill per flow step, no dangling names or paths.
want="bootstrap pb-ci pb-explain-mr pb-fix pb-mr pb-orchestrator pb-release pb-review pb-run pb-triage pb-verify"
got="$(cd "$ROOT/skills" && ls -d */ | tr -d / | tr '\n' ' ' | sed 's/ $//')"
[ "$got" = "$want" ] && ok "podbay skills are the standard set" || bad "podbay skills are the standard set (got: $got)"
got="$(cd "$ROOT/../tools/skills" && ls -d */ | tr -d / | tr '\n' ' ' | sed 's/ $//')"
[ "$got" = "grill-me grilling macos-cleaner unslop wayfinder" ] && ok "tools skills are grill-me, grilling, macos-cleaner, unslop, wayfinder" || bad "tools skills (got: $got)"
old="$(grep -rnE 'pb-ticket|pb-file-issues|pb-auto-issues|verify-ticket|pb-local-run' "$ROOT" "$ROOT/../tools" "$ROOT/../../README.md" "$ROOT/../../.claude-plugin" 2>/dev/null | grep -v 'formerly the' | grep -v '/scripts/test-kit-text.sh:')"
[ -z "$old" ] && ok "no references to removed or renamed skills" || bad "no references to removed or renamed skills ($(printf '%s' "$old" | head -1 | cut -c1-120))"
missing=""
for p in $(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]+' "$ROOT/skills" "$ROOT/reference" | sed -E 's/[.,;:)]+$//' | sort -u); do
  rel="${p#\$\{CLAUDE_PLUGIN_ROOT\}/}"
  [ -e "$ROOT/$rel" ] || missing="$missing $rel"
done
[ -z "$missing" ] && ok "every \${CLAUDE_PLUGIN_ROOT} path in skill and reference text exists" || bad "missing plugin paths:$missing"

echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]

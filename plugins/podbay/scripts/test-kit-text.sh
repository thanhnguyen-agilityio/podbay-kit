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

# Review proof, tiers, merge check, sweep (0.8.0).
has   "a blocker names a failing test or command" reference/reviewer-prompt.md 'A blocker must name a failing test'
has   "contract names the risk tiers" reference/contract.md 'Risk tier, from the changed paths'
has   "contract requires the merge check before a skill merge" reference/contract.md 'pb-merge-check.sh <iid> -R <repo>. must pass'
has   "orchestrator merges only on merge-check OK" skills/pb-orchestrator/SKILL.md 'Merge only on "merge-check: OK"'
has   "pb-review names the tier" skills/pb-review/SKILL.md 'pb-tier.sh origin/<base>'
has   "review sweep never posts or merges" skills/pb-review-sweep/SKILL.md 'never post a comment, edit an MR or issue, push, approve or merge'
has   "review sweep never sets up its own schedule" skills/pb-review-sweep/SKILL.md 'never creates or changes a schedule'
for c in fix-grill-first triage-verified mr-target review-blocker-proof review-seeded-bug; do
  [ -f "$ROOT/evals/$c/prompt.md" ] && [ -f "$ROOT/evals/$c/graders/criteria.md" ] && ok "eval $c exists" || bad "eval $c exists"
done

# The tools plugin is required; pb-triage refuses without grill answers (0.8.0).
step  "pb-triage refuses to go on without grill answers" skills/pb-triage/SKILL.md 1b 'Do not go on to step 2 without those answers'
has   "README says tools is required" ../../README.md 'tools@podbay-kit   # required'

has   "a clean rebase posts a carry-over review note" reference/contract.md 'Clean rebase of the round <k> review'
has   "the merge check is not proof of who reviewed" reference/contract.md 'consistency check, not proof of who reviewed'
has   "orchestrator runs the merge check on the author's checkout" skills/pb-orchestrator/SKILL.md 'author checkout>. is the checkout or worktree of the session that wrote the MR'
has   "needs-advisor uses the pb-tier list" reference/contract.md 'a path .pb-tier.sh. prints as .sensitive:'
has   "only a person adds pb::human-reviewed" reference/contract.md 'a skill or session never adds it'

# Roles and kickoff (0.9.0).
has   "pb-kickoff is started by hand only" skills/pb-kickoff/SKILL.md '^disable-model-invocation: true'
has   "pb-kickoff never starts or stops a session without a yes" skills/pb-kickoff/SKILL.md "never stops, restarts or starts a session without the user's yes"
step  "pb-kickoff asks for a read-back of the role and top 3 rules" skills/pb-kickoff/SKILL.md 5 'top 3 rules'
has   "pb-kickoff --dry-run changes nothing" skills/pb-kickoff/SKILL.md '.--dry-run. changes nothing'
step  "pb-kickoff asks for replies to the orchestrator" skills/pb-kickoff/SKILL.md 5 'reply by .SendMessage. to this session'
step  "pb-kickoff reports the table" skills/pb-kickoff/SKILL.md 7 'session, machine, role, read-back'
has   "the SessionStart hook runs pb-role.py" hooks/hooks.json '"SessionStart"'
has   "the SessionStart hook command is pb-role.py" hooks/hooks.json 'scripts/pb-role.py'
[ -f "$ROOT/evals/kickoff-readback/prompt.md" ] && [ -f "$ROOT/evals/kickoff-readback/graders/criteria.md" ] && ok "eval kickoff-readback exists" || bad "eval kickoff-readback exists"

# pb-release covers the website (0.8.1).
step  "pb-release has a website step" skills/pb-release/SKILL.md 4c 'marked Latest'
step  "pb-release website step never edits generated parts" skills/pb-release/SKILL.md 4c 'never edit a generated part'
step  "pb-release version bump allows the site pages" skills/pb-release/SKILL.md 5 'site pages changed in step 4c'
has   "release checklist lists step 4c" reference/release-checklist.md '^\| 4c \| Website'
step  "pb-release website step greps for stale and new versions" skills/pb-release/SKILL.md 4c "grep -nF '<x.y.z>'"
step  "pb-release step 5 calls a stale site not ready" skills/pb-release/SKILL.md 5 'is not ready'
step  "pb-release step 5 needs a Latest release notes entry unless generated" skills/pb-release/SKILL.md 5 'no Latest entry for .<x.y.z>. .skip this when step 4c listed that page as generated'
step  "pb-release release notes entry has screenshots of the changes" skills/pb-release/SKILL.md 4c 'a screenshot of each user-visible change'
step  "pb-release step 4c explains every remaining stale hit" skills/pb-release/SKILL.md 4c 'explain every hit that stays'

step  "pb-release step 9 checks the live pages" skills/pb-release/SKILL.md 9 'open the live landing and release notes pages'
has   "release rules: generated site parts are never edited" reference/release-checklist.md 'never edited by hand'
has   "release rules: a patch release repeats the website step" reference/release-checklist.md 'including the website step 4c'
step  "pb-release website step checks phone and desktop widths" skills/pb-release/SKILL.md 4c 'phone .390 px. and desktop .1280 px'
step  "pb-release website step follows the design-system rule" skills/pb-release/SKILL.md 4c 'Design system first'
for c in release-site-stale release-notes-stale; do
  [ -f "$ROOT/evals/$c/prompt.md" ] && [ -f "$ROOT/evals/$c/graders/criteria.md" ] && ok "eval $c exists" || bad "eval $c exists"
done

# Design system first covers the website (0.8.0).
has   "contract has the design-system rule for the site" reference/contract.md 'site/site.css. and .site/styleguide.html'
has   "review checklist flags raw colours in a page diff" reference/review-checklist.md 'raw colour or size'
step  "pb-fix applies the design-system rule" skills/pb-fix/SKILL.md 1c 'site/site.css'
step  "pb-triage applies the design-system rule" skills/pb-triage/SKILL.md 1c 'design-system owner'
[ -f "$ROOT/evals/review-site-raw-colour/prompt.md" ] && ok "eval review-site-raw-colour exists" || bad "eval review-site-raw-colour exists"

# Kit clean-up (0.7.0): one skill per flow step, no dangling names or paths.
want="bootstrap pb-ci pb-explain-mr pb-fix pb-kickoff pb-mr pb-orchestrator pb-release pb-review pb-review-sweep pb-run pb-triage pb-verify"
got="$(cd "$ROOT/skills" && ls -d */ | tr -d / | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')"
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

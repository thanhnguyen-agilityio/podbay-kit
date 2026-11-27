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
has   "only a person adds human-reviewed" reference/contract.md 'a skill or session never adds it'

# No branch name is built from a version (0.9.1).
# Matches are printed with what comes before them, so .podbay/release/<x.y.z>/ state folders can be left out.
hits="$(cd "$ROOT" && grep -rnoE '(\.podbay/)?((release|hotfix)/<(version|x\.y\.z)>|sync/release-<(x\.y\.z|version)>|release/<yyyymmdd>)' skills reference templates scripts evals --exclude=test-kit-text.sh --exclude-dir=results 2>/dev/null | grep -v ':\.podbay/')"
[ -z "$hits" ] && ok "no branch names built from a version" || bad "no branch names built from a version ($(printf '%s' "$hits" | head -1 | cut -c1-100))"
# develop branch model (0.10.0): all work goes to develop; a release is a Draft MR from develop into main.
step  "pb-mr: the default target is develop" skills/pb-mr/SKILL.md 2 'Else the target is .develop.'
lacks "pb-mr: no release branch target" skills/pb-mr/SKILL.md 'release/<yyyy\.mm\.dd>'
has   "pb-mr: asks first only for a person-merge target in pb-targets.sh" skills/pb-mr/SKILL.md 'PB_PERSON_MERGES. in .*pb-targets\.sh'
step  "pb-mr flags a user-visible MR into develop with no CHANGELOG line" skills/pb-mr/SKILL.md 7 'no CHANGELOG line'
has   "routing: a fix or feature branches from develop" reference/mr-checklist.md '^\| Feature or fix \| .origin/develop. \|'
has   "routing: an urgent fix branches from main and goes into main" reference/mr-checklist.md '^\| Urgent fix .*\| .origin/main. \| .hotfix/<short-name>. \| .main. \|'
has   "routing: main is merged back into develop after an urgent fix" reference/mr-checklist.md 'backmerge/main-<yyyy\.mm\.dd>'
has   "routing: old release branches are read-only" reference/mr-checklist.md 'release/\*. branches are read-only'
lacks "routing: no cherry-pick route" reference/mr-checklist.md 'cherry-pick/'
has   "a feature MR adds its own CHANGELOG line under [Unreleased]" reference/mr-checklist.md 'under .## \[Unreleased\]. in .CHANGELOG\.md.'
has   "the pb-fix worker adds the CHANGELOG line" skills/pb-fix/references/worker.md '\[Unreleased\]'
lacks "pb-fix has no hotfix cherry-pick step" skills/pb-fix/SKILL.md 'cherry-pick'
for f in skills/pb-fix/references/worker.md skills/pb-fix/references/batch.md skills/pb-fix/references/review-3.md skills/pb-triage/SKILL.md reference/preflight.md reference/review-checklist-rust.md; do
  lacks "$f works from develop, not main" "$f" 'origin/main'
done
has   "pb-review: the default base is develop" skills/pb-review/SKILL.md 'else .develop.'
has   "contract: protected branches come from pb-targets.sh" reference/contract.md 'pb-targets\.sh'
has   "contract: develop is team-shared for merges" reference/contract.md 'develop. is team-shared'
has   "orchestrator merges only outside the person-merge list" skills/pb-orchestrator/SKILL.md 'pb-targets\.sh'
lacks "pb-release: no --branch option" skills/pb-release/SKILL.md '\-\-branch'
lacks "pb-release: no release branch" skills/pb-release/SKILL.md 'release branch'
lacks "pb-release: no sync step" skills/pb-release/SKILL.md 'Sync to main|sync branch'
lacks "release checklist: no sync section or sync branch" reference/release-checklist.md 'Sync to main|Sync branch|Release branch'
step  "pb-release step 1 checks main has nothing develop lacks" skills/pb-release/SKILL.md 1 'git log --oneline --no-merges origin/develop\.\.origin/main'
step  "pb-release step 3 verifies the develop head" skills/pb-release/SKILL.md 3 'on the .develop. head'
step  "pb-release step 4 turns [Unreleased] into the version section" skills/pb-release/SKILL.md 4 'Turn .## \[Unreleased\]. into'
step  "pb-release step 5 opens one release-prep MR into develop" skills/pb-release/SKILL.md 5 'release-prep MR into .develop.'
step  "pb-release step 6 opens a Draft MR from develop into main" skills/pb-release/SKILL.md 6 'Draft MR from .develop. into .main.'
step  "pb-release step 6 keeps develop and every commit" skills/pb-release/SKILL.md 6 'no .--squash-before-merge. and no .--remove-source-branch.'
step  "pb-release step 6: a person merges after the team agrees" skills/pb-release/SKILL.md 6 'A person merges it after the team agrees'
step  "pb-release step 7 drafts the tag and Release only" skills/pb-release/SKILL.md 7 'never creates, moves or deletes a tag'
lacks "pb-release never calls the tag API" skills/pb-release/SKILL.md 'repository/tags'
has   "pb-release keeps the release host" skills/pb-release/SKILL.md 'host'
has   "release checklist names the host" reference/release-checklist.md '^\| Release host \|'
step  "pb-mr never rebases a back-merge branch" skills/pb-mr/SKILL.md 3 'backmerge/main-.. branch is never rebased'
has   "urgent fix bumps the patch version" reference/mr-checklist.md 'also bumps the patch version'
step  "pb-release step 3 records the verify head" skills/pb-release/SKILL.md 3 'verify head'
step  "pb-release step 6 checks against the verify head" skills/pb-release/SKILL.md 6 '<verify head>\.\.origin/develop'
step  "pb-release step 7 checks the merge brought exactly the release head" skills/pb-release/SKILL.md 7 'merge_commit_sha>\^2. equals .<release head>'
step  "pb-release step 0 checks the project's merge method" skills/pb-release/SKILL.md 0 'merge_method'
step  "pb-release step 5: its approval rule wins over pb-mr's" skills/pb-release/SKILL.md 5 "this skill's approval rule wins"
has   "orchestrator holds develop merges while a release MR is open" skills/pb-orchestrator/SKILL.md 'While a release MR from .develop. into .main. is open'
has   "batch worker opens MRs as Drafts" skills/pb-fix/references/worker.md 'glab mr create .*--draft'
has   "contract: back-merge and release MRs are never squashed" reference/contract.md 'except a back-merge MR and the release MR'
step  "pb-release step 0 needs squash never or default_off" skills/pb-release/SKILL.md 0 'squash_option. must be .never. or .default_off.'
step  "pb-release step 6 tells the merger not to squash" skills/pb-release/SKILL.md 6 'do not tick Squash'
step  "pb-fix: an urgent fix bumps the patch version" skills/pb-fix/SKILL.md 6 'hotfix/.. branch.*patch version'
step  "pb-mr: an urgent fix needs a version section, a back-merge no line" skills/pb-mr/SKILL.md 7 'hotfix/.. branch needs'
step  "pb-release step 7 has an urgent-fix variant" skills/pb-release/SKILL.md 7 '--urgent <iid>'
has   "a back-merge MR gets its own review on its head" reference/mr-checklist.md 'pb-review. on the back-merge MR'
has   "back-merge version conflict keeps develop's version" reference/mr-checklist.md "keep .develop.'s version"
step  "pb-release step 6 repeats the main-has-nothing-develop-lacks check" skills/pb-release/SKILL.md 6 'git log --oneline --no-merges origin/develop\.\.origin/main'
step  "pb-release --urgent still runs step 0" skills/pb-release/SKILL.md 7 'after step 0, start here'
has   "back-merge places the urgent CHANGELOG section by version" reference/mr-checklist.md 'in version order'
# Old label scheme (0.10.1): bug|feature|improvement, P1|P2|P3, area:<name>; skills never create labels.
hits="$(cd "$ROOT" && grep -rnE 'type::|priority::|area::|glab label create|pb::agent-ready' skills reference templates 2>/dev/null)"
[ -z "$hits" ] && ok "no new-scheme labels and no label creation in skills, references or templates" || bad "no new-scheme labels and no label creation ($(printf '%s' "$hits" | head -1 | cut -c1-100))"
has   "contract: type labels are bug, feature, improvement" reference/contract.md '^\| Type \| .bug., .feature., .improvement.'
has   "contract: priority labels are P1, P2, P3" reference/contract.md '^\| Priority \| .P1., .P2., .P3.'
has   "contract: area labels are the repo's area:<name> labels" reference/contract.md '^\| Area \| .*area:<name>'
has   "contract: skills never create a label" reference/contract.md 'never creates a label'
has   "contract: the merge gate label is human-reviewed, added by a person" reference/contract.md 'a person adds .human-reviewed.'
has   "contract: needs-human is never approval" reference/contract.md '.needs-human. .*is never approval'
hits="$(cd "$ROOT" && grep -rn 'pb::human-reviewed' skills reference templates scripts --exclude='test-*.sh' 2>/dev/null)"
[ -z "$hits" ] && ok "the gate label is human-reviewed everywhere" || bad "the gate label is human-reviewed everywhere ($(printf '%s' "$hits" | head -1 | cut -c1-100))"
has   "batch mode orders by P1, P2, P3" skills/pb-fix/references/batch.md '.P1. -> .P2. -> .P3.'
has   "batch mode stops when a state label is missing" skills/pb-fix/references/batch.md 'state label .*does not exist.*stop and report'
has   "filing uses agent-ready" skills/pb-triage/references/file.md '.agent-ready.'
has   "batch mode drops spikes and epics by the triage file's type" skills/pb-fix/references/batch.md 'triage file.s type column'
has   "filing: spike and epic rows get no agent-ready" skills/pb-triage/references/file.md 'a spike or epic row gets no .agent-ready.'
has   "filing: the triage comment starts with Kind: for a task, spike or epic" skills/pb-triage/references/file.md 'comment starts with .Kind: <kind>.'
has   "ticket format: type table uses the old labels" reference/ticket-format.md '^\| Bug \| .bug. \|'
[ ! -e "$ROOT/templates/release/slack-freeze.md" ] && [ -f "$ROOT/templates/release/slack-release-start.md" ] && ok "the freeze notice is replaced by a release-start notice" || bad "the freeze notice is replaced by a release-start notice"
[ -f "$ROOT/evals/release-develop-flow/prompt.md" ] && [ -f "$ROOT/evals/release-develop-flow/graders/criteria.md" ] && ok "eval release-develop-flow exists" || bad "eval release-develop-flow exists"

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

# Visual evidence on every bug report (0.9.2): a screenshot, video or GIF.
has   "bug template marks Evidence as required, with a screenshot, video or GIF" templates/issue_templates/Bug.md '^<!-- Required\..*screenshot, video or GIF'
has   "ticket format marks the bug's Evidence as required" reference/ticket-format.md 'Required: at least one screenshot, video or GIF'
has   "Definition of Ready requires visual evidence on a bug" reference/ticket-format.md '^12\. \*\*Visual evidence\.\*\*'
step  "pb-triage flags a bug with no visual evidence at gate 1" skills/pb-triage/SKILL.md 6b 'no visual evidence'
has   "pb-triage --verified refuses to file a bug with no visual evidence" skills/pb-triage/references/verified.md 'not filed: no visual evidence'
has   "pb-triage --file refuses to file a bug with no visual evidence" skills/pb-triage/references/file.md 'A bug with none is not created.*not filed: no visual evidence'
step  "pb-mr flags a bug MR with no visual evidence" skills/pb-mr/SKILL.md 7 'no visual evidence'
step  "pb-mr blocks --ready on a bug MR with no visual evidence, and keeps the Draft" skills/pb-mr/SKILL.md 7 'no visual evidence.*do not allow .--ready.: the MR stays Draft'
step  "pb-triage --verified checks visual evidence before the approval question" skills/pb-triage/references/verified.md 5 'no visual evidence'
has   "batch review 3 needs visual evidence on a bug fix" skills/pb-fix/references/review-3.md 'no visual evidence'
has   "MR checklist asks a bug MR for a screenshot, video or GIF" reference/mr-checklist.md 'bug fix.*screenshot, video or GIF'
for c in triage-bug-evidence ci-docker-start; do [ -f "$ROOT/evals/$c/prompt.md" ] && [ -f "$ROOT/evals/$c/graders/criteria.md" ] && ok "eval $c exists" || bad "eval $c exists"; done

step  "pb-triage --file uploads triage's own evidence to a GitLab row" skills/pb-triage/references/file.md 4 'Internal block lists.*## Evidence'
# Sessions start Docker and take screenshots themselves (0.9.2).
hits="$(grep -rnE 'tell the user to start Docker|Start Docker Desktop|only the user starts Docker' "$ROOT/skills" "$ROOT/reference" "$ROOT/scripts" | grep -v '/scripts/test-kit-text.sh:')"
[ -z "$hits" ] && ok "no text leaves starting Docker to the user" || bad "no text leaves starting Docker to the user ($(printf '%s' "$hits" | head -1 | cut -c1-120))"
has   "pb-ci starts Docker through docker-up.sh" skills/pb-ci/pb-ci.sh 'docker-up\.sh'
has   "contract: sessions take their own screenshots with pb-shot.sh" reference/contract.md 'Screenshots: the session takes them itself.*pb-shot\.sh'
has   "contract: Screen Recording caveat names the error and the hand-off" reference/contract.md 'could not create image from window.*exact .screencapture. command'
has   "pb-run takes window screenshots with pb-shot.sh and checks private data" skills/pb-run/SKILL.md 'pb-shot\.sh.*private data'
step  "pb-triage's own screenshot points to the Screen Recording caveat" skills/pb-triage/SKILL.md 6b 'Screen Recording caveat'
step  "pb-verify recordings point to the Screen Recording caveat" skills/pb-verify/SKILL.md 5 'could not create image from window'
has   "recording reference has the Screen Recording caveat" skills/pb-verify/references/recording.md 'could not create image from window'

# Unattended UI test in four tiers (0.9.3): tiers 1-3 run without computer use; tier 3 is a real-window check.
has   "ui-tiers: tier 1 runs the UI tests with a temp HOME" skills/pb-verify/references/ui-tiers.md 'HOME="\$H" cargo test --bin podbay ui::'
has   "ui-tiers: tier 2 diffs screenshots against the previous release tag" skills/pb-verify/references/ui-tiers.md 'previous release tag.*'
has   "ui-tiers: tier 2 makes a difference picture" skills/pb-verify/references/ui-tiers.md 'blend=all_mode=difference'
has   "ui-tiers: tier 3 uses ui-window-check.sh" skills/pb-verify/references/ui-tiers.md 'ui-window-check\.sh'
has   "ui-tiers: tier 3 asks the user before the appearance changes" skills/pb-verify/references/ui-tiers.md 'only after they agree'
has   "ui-tiers: never save an unblanked real-window capture" skills/pb-verify/references/ui-tiers.md 'Never save or post an unblanked'
has   "ui-tiers: tier 4 is only for OS and real-machine rows" skills/pb-verify/references/ui-tiers.md 'Tier 4.*OS and real-machine rows only'
has   "pb-verify runs tiers 1 to 3 before computer use" skills/pb-verify/SKILL.md 'ui-tiers\.md.*tiers 1 to 3'
has   "pb-verify --installed runs tiers 1 to 3 before computer use" skills/pb-verify/references/installed.md 'ui-tiers\.md'
step  "pb-release step 3 runs the four tiers" skills/pb-release/SKILL.md 3 'ui-tiers\.md'
lacks "pb-release step 3 no longer starts with a computer-use click-through" skills/pb-release/SKILL.md 'ask the user to run a desktop computer-use session for the UI click-through'
has   "release checklist step 3 names the tiers" reference/release-checklist.md '^\| 3 \| Verify \|.*tiers'
has   "ui-window-check refuses without --yes" skills/pb-verify/ui-window-check.sh 'rerun with --yes after they agree'
has   "ui-window-check restores the appearance in a trap" skills/pb-verify/ui-window-check.sh "trap 'rc=\\\$\?; restore"
has   "ui-window-check blanks the bottom bar before saving" skills/pb-verify/ui-window-check.sh 'drawbox=x=0:y=\$\(\(h - bb\)\)'
has   "contract caveat: the grant goes to the tmux server, not the terminal" reference/contract.md 'tmux server.*responsible'
has   "contract caveat: start the tmux server from the granted terminal" reference/contract.md 'tmux kill-server.*from a new window of the granted terminal'
has   "contract caveat: names the display error too" reference/contract.md 'could not create image from display'
has   "recording reference: caveat points to the tmux server" skills/pb-verify/references/recording.md 'responsible for the tmux server'
has   "pb-shot.sh: caveat points to the tmux server" scripts/pb-shot.sh 'tmux server'
[ -d "$ROOT/evals/verify-ui-tiers" ] && ok "eval verify-ui-tiers exists" || bad "eval verify-ui-tiers exists"

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

# Ticket status (0.10.2): In Process -> In Review -> On Dev; the ticket closes on the merge into main.
has   "contract has a Ticket status section" reference/contract.md '^## Ticket status'
has   "contract: the three status labels in order" reference/contract.md 'In Process.*In Review.*On Dev'
has   "contract: status edits need no approval, closing does" reference/contract.md 'status label.*no approval.*[Cc]losing'
has   "contract: assignee is a team value, never in the kit" reference/contract.md 'ticket-assignee:'
has   "contract: a missing status label stops the step" reference/contract.md 'status label is missing.*stop'
has   "contract: merge into develop never closes the ticket" reference/contract.md 'On Dev.*never close'
has   "pb-orchestrator sets In Process and the assignee at start" skills/pb-orchestrator/SKILL.md 'In Process.*ticket-assignee'
has   "pb-orchestrator briefs carry the status flow" skills/pb-orchestrator/SKILL.md '[Bb]rief.*Ticket status'
has   "pb-orchestrator sets On Dev after a merge into develop" skills/pb-orchestrator/SKILL.md "merge into .develop.*--unlabel 'In Process,In Review' --label 'On Dev'"
has   "pb-orchestrator finds an epic's child tickets by command" skills/pb-orchestrator/SKILL.md 'glab mr list -R <repo> --merged --target-branch feat/<epic-name>'
has   "status: starting removes any older status label" reference/contract.md "--unlabel 'In Review,On Dev' --label 'In Process'"
has   "pb-fix batch worker sets In Process" skills/pb-fix/references/worker.md "In Process"
has   "pb-release skips the close step with --urgent" skills/pb-release/SKILL.md 'With .--urgent., skip the ticket close'
has   "pb-mr sets In Review only when the MR is ready" skills/pb-mr/SKILL.md "ready for review.*glab issue update <n> -R <repo> --unlabel 'In Process' --label 'In Review'"
has   "pb-mr keeps In Process while Draft" skills/pb-mr/SKILL.md 'Draft.*In Process|In Process.*Draft'
has   "pb-release closes On Dev leftovers after the merge into main" skills/pb-release/SKILL.md 'On Dev.*glab issue close|glab issue close.*On Dev'
has   "status: assignee is added with +, not replaced" reference/contract.md "--assignee '\\+<ticket-assignee>'"
has   "status: label check reads 100 labels" reference/contract.md 'glab label list -R <repo> --per-page 100'
has   "status: a ready MR found by the orchestrator moves to In Review; back to Draft moves back" skills/pb-orchestrator/SKILL.md 'no longer a Draft.*In Review.*Draft again.*In Process'
has   "status: the flow needs main as the default branch" reference/contract.md 'default branch.*main'
has   "pb-release checks the default branch is main" skills/pb-release/SKILL.md 'default_branch'
has   "pb-release counts epic child tickets at the close step" skills/pb-release/SKILL.md 'feat/<epic-name>.*On Dev|On Dev.*feat/<epic-name>'
has   "status: every Closes line counts" reference/contract.md 'each issue in a .Closes'
has   "pb-fix sets In Process when it starts a ticket on its own" skills/pb-fix/SKILL.md 'In Process'
step  "pb-orchestrator brief carries the design-system line" skills/pb-orchestrator/SKILL.md 4 'Do not edit src/ui/kit\*, src/ui/theme\*, src/ui/sink\.rs or tokens; only the design-system owner does\. If the fix needs a design part, stop and ask the orchestrator\.'
has   "role map: the machine qualifier is documented" ../../CLAUDE.md '@<machine>'
has   "pb-kickoff knows map lines with @<machine>" skills/pb-kickoff/SKILL.md '@<machine>'
has   "README documents the machine qualifier and PB_MACHINE" ../../README.md '@<machine>.*PB_MACHINE'

# Outside reports (0.10.3): GitLab lifecycle from New to reporter-notified.
OR=reference/outside-reports.md
[ -f "$ROOT/$OR" ] && ok "outside-reports reference exists" || bad "outside-reports reference exists"
has   "outside: the states in order" $OR 'New.*Acknowledged.*Triaged.*Needs Info.*In Process.*In Review.*On Dev.*Closed.*reporter-notified'
has   "outside: the four source labels" $OR 'source::client.*source::team.*source::support.*source::dm'
has   "outside: one source label per ticket" $OR 'one source label'
has   "outside: type label bug or Feature request" $OR "'Feature request'"
has   "outside: the Reporter block" $OR 'Reporter: <name> \(<role>\) · Source: <link> · Reply to: <thread \| DM to <person>>'
has   "outside: the Acknowledged/Notified line" $OR 'Acknowledged: <date> · Notified: —'
has   "outside: the Acknowledged comment" $OR 'Acknowledged: replied to reporter, logged as #<n>'
has   "outside: resolution fixed" $OR '^- `Resolution: Fixed in <version>`'
has   "outside: resolution duplicate" $OR '^- `Resolution: Duplicate of #<n>`'
has   "outside: resolution wont-fix" $OR '^- `Resolution: Won.t fix: <why>`'
has   "outside: resolution cannot-reproduce" $OR '^- `Resolution: Cannot reproduce`'
has   "outside: resolution no-response" $OR '^- `Resolution: No response`'
has   "outside: Needs Info closes after 14 days with a yes" $OR '14 days.*yes'
has   "outside: the Notified comment" $OR 'Notified: <date>, <link>'
has   "outside: a missing label stops, never created" $OR 'missing.*stop.*never create'
has   "outside: the session never sends the reply" $OR 'never sends'
has   "contract points to outside reports" reference/contract.md 'outside-reports\.md'
has   "pb-triage acknowledges and triages outside reports" skills/pb-triage/SKILL.md 'outside-reports\.md'
has   "pb-orchestrator lists stale Needs Info" skills/pb-orchestrator/SKILL.md 'Needs Info.*14 days'
has   "pb-fix sets Needs Info for an outside report it cannot build" skills/pb-fix/SKILL.md '1a2.*source::.*Needs Info'
has   "pb-release drafts replies for client and team reporters too" skills/pb-release/SKILL.md 'source::client. and .source::team.*the user decides where'
has   "pb-release posts Resolution before the close" skills/pb-release/SKILL.md 'Resolution:. before .glab issue close'
has   "pb-release --urgent asks for the comments on their own" skills/pb-release/SKILL.md 'With .--urgent., ask for the comments on their own'
has   "pb-release lists closed outside reports not yet notified" skills/pb-release/SKILL.md 'source::. label and no .reporter-notified'
has   "pb-release posts the Fixed resolution and drafts reporter replies" skills/pb-release/SKILL.md 'Resolution: Fixed in <x\.y\.z>.*reporter-notified'

# Idle sessions (0.10.3): stop a worker idle for 30 minutes after a check; resume with --resume latest.
IS=reference/idle-sessions.md
[ -f "$ROOT/$IS" ] && ok "idle-sessions reference exists" || bad "idle-sessions reference exists"
has   "idle: 30 minutes and PB_IDLE_MINUTES" $IS '30 minutes.*PB_IDLE_MINUTES|PB_IDLE_MINUTES.*30'
has   "idle: work pushed check" $IS 'dirty. 0 and .ahead. 0.*rev-parse @\{u\}'
has   "idle: no build or test running" $IS '[Nn]o build or test'
has   "idle: no prompt waiting" $IS 'waiting_for'
has   "idle: resume command" $IS 'podbay-dev start <project> <repo> --ws <ws> --resume latest'
has   "idle: only the orchestrator, the supervisor and a watching session stay up" $IS 'orchestrator.*supervisor.*watch'
has   "idle: standing roles are stopped too" $IS 'standing roles'
has   "idle: a failed check is reported, never stopped" $IS 'reported, never stopped'
has   "pb-orchestrator links the idle rule" skills/pb-orchestrator/SKILL.md 'idle-sessions\.md'
has   "pb-kickoff expects stopped workers" skills/pb-kickoff/SKILL.md 'idle-sessions\.md'

# Private names never go in the kit. The list itself is private: set PB_PRIVATE_NAMES (an ERE) locally to check it.
if [ -n "${PB_PRIVATE_NAMES:-}" ]; then
  hit="$(grep -rEn -- "$PB_PRIVATE_NAMES" "$ROOT/skills" "$ROOT/reference" "$ROOT/templates" "$ROOT/scripts" "$ROOT/evals" "$ROOT/../../README.md" "$ROOT/../../CHANGELOG.md" "$ROOT/../../CLAUDE.md" 2>/dev/null | grep -v '/evals/results/' | head -1)"
  [ -z "$hit" ] && ok "no private names in the kit text" || bad "no private names in the kit text ($(printf '%s' "$hit" | cut -c1-100))"
fi
has   "idle: a branch with no upstream fails the check" reference/idle-sessions.md 'no upstream.*fails'
has   "idle: checkouts on every machine" reference/idle-sessions.md 'podbay-dev checkouts --all'
has   "idle: nothing queued, by podbay-dev queue ls --all" reference/idle-sessions.md 'podbay-dev queue ls --all'
has   "idle: no message for 30 minutes read from podbay-dev ls" reference/idle-sessions.md 'podbay-dev ls.*since'
lacks "idle: git and ps never run through --on" reference/idle-sessions.md '(rev-parse|ps).*--on <machine>'
has   "pb-orchestrator: the idle rule is an exception to asking before a stop" skills/pb-orchestrator/SKILL.md 'except under the idle rule'
has   "pb-release --urgent also handles the urgent MR's outside reports" skills/pb-release/SKILL.md 'With .--urgent <iid>., read that MR.s .Closes #<n>. lines'
has   "idle: night is a team value" reference/idle-sessions.md 'night:'
has   "outside: 14 days counted from the Needs Info comment" reference/outside-reports.md '14 days.*from the date of the .Needs Info. comment'
has   "pb-triage closes Duplicate, Won't fix and Cannot reproduce with a reply" skills/pb-triage/SKILL.md 'Duplicate of #<n>.*Won.t fix.*Cannot reproduce.*reporter-notified'
has   "pb-release finds auto-closed outside reports" skills/pb-release/SKILL.md 'glab issue view <n> -R <repo> --output json.*source::'

echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]

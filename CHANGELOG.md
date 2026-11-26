# Changelog

One entry per podbay plugin version, newest first. Older versions: see `git log`.

## podbay 0.10.0 - 2026-11-26

- Branch model with `develop` (team decision of 2026-11-26): all work goes into `develop`; `develop` reaches `main` only through the release MR. No more release, hotfix, cherry-pick or sync branches; old `release/*` branches are read-only.
- New `scripts/pb-targets.sh`: the one list of protected branches, sourced by `pb-guard.sh` and `pb-merge-check.sh`. `PB_PERSON_MERGES` is `main master release/*`, so only a person merges there; `develop` is team-shared, so a team member or the orchestrator may merge into it, and adding it to that line makes it person-only. `PB_NO_PUSH` is `main master develop release/*`, so the guard now also blocks a direct push to `develop` and to old release branches (the `PB_KIT_REPO` exception stays for `main` only). When the file is missing, every push and merge is blocked.
- `pb-mr`, `pb-fix`, `pb-triage`, `pb-review`, the batch worker, preflight, the ticket format and the contract work from `origin/develop`, with `develop` as the default target. A Draft MR into `develop` is pushed and opened without asking. Urgent fix: a `hotfix/<short-name>` branch from `main` into `main`, which a person merges, then a `backmerge/main-<yyyy.mm.dd>` MR into `develop` with no squash.
- CHANGELOG between releases: each user-visible MR into `develop` adds its own line under `## [Unreleased]`, and `pb-mr` flags "no CHANGELOG line".
- `pb-release`, with its weekly host:
  - start notice and merged list since the last tag on `develop`, plus a check that `main` has no commits `develop` lacks;
  - `develop`-head health and verify (UI tiers, unchanged);
  - one release-prep MR into `develop`, which turns `[Unreleased]` into the version section and holds the guide, site and version bump;
  - a Draft release MR from `develop` into `main`: a merge commit, no squash, `develop` kept; a person merges it after the team agrees, and it is checked for anything merged after verify;
  - tag and GitLab Release drafts for the person who tags (`tagger:`); the skill never creates, moves or deletes a tag.
  - The freeze template is replaced by `slack-release-start.md`; `release-checklist.md` adds the `host:` and `tagger:` values and drops the sync section.
- Tests: test-pb-guard.sh 119 pass (11 new: merge into `develop` allowed, pushes to `develop` and old release branches blocked, the lists, and a flipped copy that makes `develop` person-only); test-merge-check.sh 33 pass (2 new); test-kit-text.sh 155 pass (3 old branch-name cases replaced by 39 develop-model cases).
- Evals:
  - new `release-develop-flow`;
  - `mr-target` now covers the `develop` default and the missing CHANGELOG line;
  - `release-notes-stale`, `release-site-stale` and the three review evals now use `develop`.

## podbay 0.9.3 - 2026-11-25

- Unattended UI test in four tiers (decision of 2026-11-25), so verify runs without computer use: new `skills/pb-verify/references/ui-tiers.md`. Tier 1: `cargo test --bin podbay ui::` with a temp `HOME`. Tier 2: the screenshot test at the head and at the previous release head, with a difference picture per changed PNG; every change must trace to a merged MR. Tier 3: the real window, no clicks, through the new `skills/pb-verify/ui-window-check.sh`: it presets `"theme"` in the build's `settings.json`, sets the macOS appearance, starts the window, captures it with `screencapture -l` checks that the page follows the theme, and compares the title bar and status bar with the page. With `--start` it finds the window by the started process group (macOS hides window titles without the grant) and refuses while an old window with that title is open. It refuses to run without `--yes` (the user agrees first, because their desktop appearance changes), restores the appearance and the settings file in a trap on every exit (exit 5 if the restore does not take), and blanks the status bar (it names the signed-in account) and any `--blank` box before the picture is saved; the raw capture is never kept. Tier 4: a short checklist for OS and real-machine rows only. pb-verify (both modes) and pb-release step 3 run tiers 1 to 3 first; the release checklist row 3 names the tiers.
- Screen Recording caveat corrected: macOS checks the grant against the app responsible for the tmux server (the terminal that started it), and only for a server started after the grant. A server started before the grant, or by a service, fails with "could not create image from window" or "from display" even after the terminal restarts. The fix is the user's: `tmux kill-server`, then a new server from a window of the granted terminal. Updated in contract.md, recording.md, pb-run and pb-shot.sh.
- Tests: test-pb-helpers.sh 37 pass (25 new, with fake osascript, swift and screencapture and real ffmpeg pictures: the PASS and FAIL maths, a page that ignores the preset, blanking, the restore on capture failure, no window, TERM and a restore that does not take, the started window and its grandchildren stopped, an appearance change that is refused, Theme Dark PASS and FAIL, an old window already open, a window found by its process group when titles are hidden); test-kit-text.sh 119 pass (21 new). New eval `verify-ui-tiers`: 0.00 on 0.9.2, 1.00 on 0.9.3. Full eval run: all 12 cases at 1.00 (triage-bug-evidence after one rerun: a run had timed out at 300 s).
- Review: 3 isolated rounds on Opus (claude-opus-5-5), no blockers in any round. Round 1 (7 should-fix: a false PASS when the preset did not take, the started window left running, an unchecked backup, untested preset and signals, wrong path wording), round 2 (4 should-fix: a second signal could cut the restore, grandchildren survived, a refused appearance change could pass, the start command was not named) and round 3 (3 should-fix: window titles are hidden without the grant, an old open window could be measured, no Theme Dark tests) all fixed with tests that fail first; no round 4, by the owner's choice.
- Live check after the tmux server was restarted from the granted terminal: `pb-shot.sh` captured a window (exit 0); before that restart it failed with "could not create image from window", as the caveat says.

## podbay 0.9.2 - 2026-11-25

- Visual evidence on every bug report (decision of 2026-11-25): a bug needs at least one screenshot, video or GIF that shows the problem; with nothing on screen, a screenshot of the terminal or log counts. The bug issue template and the ticket format mark `## Evidence` as required, and the Definition of Ready has item 12. pb-triage takes its own screenshot of the reproduction when the reporter gave none, else marks the item "ask: visual evidence" (a GitLab row gets a comment asking the reporter and no `pb::agent-ready`). `--verified` shows "no visual evidence" in the approval table and leaves those tickets out of the create count; `--verified` and `--file` never file a bug without one ("not filed: no visual evidence"); no way to skip. pb-mr flags a bug MR without a screenshot, video or GIF and blocks `--ready` (the Draft still opens); pb-fix batch review 3 treats it as not confident. Eval `triage-bug-evidence`: 0.00 on 0.9.1, 1.00 on 0.9.2 (3 runs each, Sonnet judge).
- Sessions start Docker and take screenshots themselves (decision of 2026-11-25). pb-ci runs `skills/pb-ci/docker-up.sh`: when `docker info` fails it starts Docker (`open -g -a Docker`) and waits up to `PBCI_DOCKER_WAIT` seconds (default 180); on Linux it stops with exit 4 and a message. New `scripts/pb-shot.sh <pid> <out.png>` screenshots one process's window (`screencapture -l <window id>`). The contract, pb-run and the recording reference say the session takes its own screenshots, checks them for private data and saves them, plus the Screen Recording caveat: a session started before the grant fails with "could not create image from window" until the terminal app and tmux server restart, and then reports the exact command for the user instead of trying workarounds. Tests: `test-pb-helpers.sh`, 12 cases. Eval `ci-docker-start`: 0.00 on 0.9.1, 1.00 on 0.9.2 (3 runs each, Sonnet judge). Review: 3 isolated rounds on Opus (claude-opus-5-5), no blockers in rounds 1 and 3; round 2's blocker (this eval's prompt) and every should-fix and nit item fixed; no round 4, by the owner's choice.

## podbay 0.9.1 - 2026-11-25

- Branch names follow the release date (decision of 2026-11-25): release branch `release/<yyyy.mm.dd>`, hotfix branch `hotfix/<yyyy.mm.dd>-<short-name>` (it targets the release branch of the same date), sync branch `sync/release-<yyyy.mm.dd>-<n>`. Replaces the version-based names in pb-mr, pb-fix, pb-review, the reviewer prompt, the MR checklist and the release checklist's sync branch. The hotfix date is the release branch's cut date; pb-mr stops and asks when that release branch does not exist. A text test (skills, references, templates, scripts, evals) rejects version-based branch names.

## podbay 0.9.0 - 2026-11-25

- SessionStart hook `scripts/pb-role.py`: on startup, resume, compact and clear it adds the role file for the current checkout to the session's context. The role map comes from the env var `PB_ROLE_MAP` (or a `role-map:` line in the checkout's `.podbay/roles.md`); map lines are `` - `~/path` = role ``, the longest matching path wins, the role file is `<map folder>/<role>.md`, cut at 8,000 characters. Paths must be absolute or start with `~`; a `role-map:` inside the git checkout, or a role file that leads out of the map folder (a symlink), is ignored; the hook has a 5-second timeout. No map, no match or any error: no output. Tests: `test-pb-role.sh`, 23 cases. Known limit: a `role-map:` line can name a map in another checkout; `PB_ROLE_MAP` is the recommended setup.
- New skill `pb-kickoff` (start by hand): after a break the orchestrator pulls, checks every session and machine, starts or restarts missing ones only after the user's yes, sends each its role, checks each read-back of the role and top 3 rules, fixes wrong ones, and reports a table. Eval `kickoff-readback`: 1.00 (3 runs, Sonnet judge); the first run scored 0.67 until one grader point accepted any wording for a stuck session.
- Isolated review: fresh Opus agent, round 1: no blockers; its should-fix items (repo-supplied role maps, symlinked role files, missing tests, free disk on other machines, team names in the eval) are fixed here. Round 2: no blockers; its should-fix items (a role map from a subfolder, relative paths, where sessions reply, `--dry-run` that changed things) are fixed here. Round 3 (the last): no blockers; `claude plugin update` now names the plugin, and the cross-checkout map limit is documented instead of blocked, because the team map itself lives in a git checkout.

## podbay 0.8.1 - 2026-11-22 (tools 0.3.1)

- `pb-release` step 4c, Website: the release notes page gets a new entry marked Latest with the known issues and a screenshot of each user-visible change; the landing or download page gets "What's new", the Download button version, installer file names and changed feature texts; touched guide pages are updated. Hand-written parts only (never what `deploy.sh` or the site build fills in), the site design-system rule, and a check at phone and desktop widths. Step 5's `git diff --stat` allow-list includes those site pages. After the deploy, step 9 checks the live pages; a patch release repeats step 4c. The landing page must show `<x.y.z>` in every hand-written version spot. Evals `release-site-stale` (landing page left stale) and `release-notes-stale` (release notes page left stale): each 0.00 before, 1.00 after (3 runs each, Sonnet judge).
- Evals now use a Sonnet judge (the default Haiku judge failed correct answers); the seeded-bug grader is a checklist. All 8 cases score 1.00 (3 runs each). triage-verified first scored 0.67, because pb-triage correctly stopped when `tools` was not loaded in the eval. Its grader and fix-grill-first's now accept that stop, because the eval sandbox does not load `tools`; a stopgap until evals can load both plugins.
- Isolated review: fresh Fable agents (Opus out of quota). Rounds 1 and 2: no blockers; their should-fix items are fixed here.
- `tools` 0.3.1: ships the wayfinder note from 0.8.0 (on GitLab use `decision:*` labels; start by hand only) to installed machines.

## podbay 0.8.0 - 2026-11-21

- New skill `pb-review-sweep`: one isolated review round on each open MR whose head has no review; never posts, edits or merges; findings go to the author session or the owner list; log in `.podbay/review-sweep/<date>.md`. Meant for a weekday schedule the owner sets up.
- `scripts/pb-merge-check.sh`: before an orchestrator merge into an integration branch, the reviewed commit, the pb-ci commit and the MR head must be the same, and a sensitive change needs `pb::human-reviewed`; prints the merge pinned with `--sha`. It checks commits and the label, not findings; only a person adds the label. A clean rebase carries the review over with a note on the new head. A light change passes without a pb-ci log. Tests: `test-merge-check.sh`, 31 cases (renamed, nested and mixed-case sensitive paths, partial pb-ci logs, the bold Reviewer line, review in an MR note).
- Risk tiers (`scripts/pb-tier.sh`, contract): light (docs and site only, one short round) and full (full review and pb-ci); sensitive paths also need a person's review note.
- Reviewer prompt: a blocker must name a failing test or a command with its output; otherwise it is at most should fix.
- Six behaviour evals in `evals/` (`claude plugin eval`): pb-fix grills first, pb-triage `--verified`, pb-mr target rule, a blocker needs proof, a seeded off-by-one bug, and a raw colour in a site page. All score 1.00 (3 runs each). Without their rule, blocker-proof scored 0.33 and site raw colour 0.00.
- Design system first covers the website: site pages use only parts from `site/site.css` and `site/styleguide.html`; a missing part goes to the design-system owner first; page-level `<style>`, `style=` and raw colours or sizes in a page diff are should fix (contract, pb-fix 1c, pb-triage 1c, review checklist). Eval `review-site-raw-colour`.
- The `tools` plugin is now required with `podbay` (pb-triage and pb-fix run `tools:grilling` first); README, install steps and contract say so. pb-triage now refuses to go past its grill step without answers or `skip grill: <reason>`, like pb-fix; both stop if `tools` is missing.
- Isolated review: 3 rounds by fresh Sonnet agents, because Opus was out of quota. By pb-review's own rule a non-Opus review does not count as the isolated review; Thanh chose to accept it for this release. Round 3: no blockers; its four should-fix items are fixed here, without a round 4.
- `tools` wayfinder: on GitLab use `decision:*` labels; start by hand only.

## podbay 0.7.1 - 2026-11-21 (tools 0.3.0)

- Grill first: every task, feature or bug, starts with grill-me before any code (contract, "Grill first"). pb-triage and pb-fix run it as step 1b; pb-fix will not code without the answers in the ticket, or a `skip grill: <reason>` from the person.
- `tools`: `grill-me` restored (removing it in 0.7.0 was a mistake); it runs `grilling`, which stays as the engine. Source: Matt Pocock, aihero.dev/skills-grill-me, code in mattpocock/skills, MIT.
- `tools`: `wayfinder` added (plan work too big for one session as a map of decision tickets). Source: Matt Pocock, aihero.dev/skills-wayfinder, code in mattpocock/skills, MIT. Not yet wired into pb-* steps.

## podbay 0.7.0 - 2026-11-21 (tools 0.2.0)

Kit clean-up: one standard flow with one skill per step (pb-triage, pb-fix, pb-review, pb-mr, a person merges, pb-release, pb-verify).
- `pb-ticket` and `pb-file-issues` merged into `pb-triage` (`--verified`, `--file`).
- `pb-auto-issues` merged into `pb-fix` as batch mode (several issues or `open`); its Rust review checklist moved to `reference/review-checklist-rust.md`.
- `verify-ticket` merged into `pb-verify` (`--installed`).
- `pb-local-run` moved into the kit as `pb-run`.
- `tools`: `grill-me` removed; use `grilling`.
- New text tests: the skill list, no references to removed skills, and every plugin path named in skill text exists.

## podbay 0.6.12 - 2026-11-21

- `private-ref-check.sh` (and so pb-guard) allows a link to a published artifact page, `claude.ai/artifact/<id>`. Links to sessions, chats, projects and every other `claude.ai` URL still block, and the message names the one allowed kind. The contract says to share the artifact with "Anyone with the link" first.

## podbay 0.6.11 - 2026-11-21

- pb-guard blocks `cargo build|test|clippy|run` and `pb-ci.sh` when free disk is under a floor (default 10 GB, env `PB_DISK_FLOOR_GB`), and names what to prune. It counts only a cargo or pb-ci command in command position (also after `VAR="x y"`, `env`, `time`, `nice -n N`, flags before the subcommand, or a path to cargo); a floor that is not a whole number of 1 to 6 digits falls back to 10.
- pb-review writes each round's MR comment draft in plain terms from the diff and runs `private-ref-check.sh` on it; pb-mr runs it again right before each post. The reviewer names findings by place, never by number or id.
- The isolated reviewer builds in a `<target dir>` the caller passes, with `CARGO_INCREMENTAL=0`, instead of a hard-coded shared folder.
- New `scripts/test-kit-text.sh` checks rules that live in skill and reference text.
- `PB_FREE_GB_OVERRIDE` (fake free space) is read only when `PB_GUARD_TEST=1`.

# Changelog

One entry per podbay plugin version, newest first. Older versions: see `git log`.

## podbay 0.8.0 - 2026-11-21

- New skill `pb-review-sweep`: one isolated review round on each open MR whose head has no review; never posts, edits or merges; findings go to the author session or the owner list; log in `.podbay/review-sweep/<date>.md`. Meant for a weekday schedule the owner sets up.
- `scripts/pb-merge-check.sh`: before an orchestrator merge into an integration branch, the reviewed commit, the pb-ci commit and the MR head must be the same, and a sensitive change needs `pb::human-reviewed`; prints the merge pinned with `--sha`. It checks commits and the label, not findings; only a person adds the label. A clean rebase carries the review over with a note on the new head. Tests: `test-merge-check.sh`, 29 cases (renamed, nested and mixed-case sensitive paths, partial pb-ci logs, the bold Reviewer line, review in an MR note).
- Risk tiers (`scripts/pb-tier.sh`, contract): light (docs and site only, one short round) and full (full review and pb-ci); sensitive paths also need a person's review note.
- Reviewer prompt: a blocker must name a failing test or a command with its output; otherwise it is at most should fix.
- Six behaviour evals in `evals/` (`claude plugin eval`): pb-fix grills first, pb-triage `--verified`, pb-mr target rule, a blocker needs proof, a seeded off-by-one bug, and a raw colour in a site page. All score 1.00 (3 runs each). Without their rule, blocker-proof scored 0.33 and site raw colour 0.00.
- Design system first covers the website: site pages use only parts from `site/site.css` and `site/styleguide.html`; a missing part goes to the design-system owner first; page-level `<style>`, `style=` and raw colours or sizes in a page diff are should fix (contract, pb-fix 1c, pb-triage 1c, review checklist). Eval `review-site-raw-colour`.
- The `tools` plugin is now required with `podbay` (pb-triage and pb-fix run `tools:grilling` first); README, install steps and contract say so. pb-triage now refuses to go past its grill step without answers or `skip grill: <reason>`, like pb-fix; both stop if `tools` is missing.
- Isolated review: a fresh Sonnet agent (Opus was out of quota), not a person.
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

# podbay-claude-kit

Claude Code plugin marketplace (`podbay-kit`) with one plugin, `podbay`: skills, a PreToolUse guard hook and reference docs for working on the Pod Bay repo. `README.md` has install and usage.

## Commands
- `claude plugin validate .` and `claude plugin validate plugins/podbay` : both must pass. Only the missing-icon/LICENSE warning is expected.
- `bash plugins/podbay/scripts/test-pb-guard.sh` : the guard's tests; 108 pass, 0 fail.
- `bash plugins/podbay/scripts/test-kit-text.sh` : rules in skill and reference text; 60 pass, 0 fail.
- `bash plugins/podbay/scripts/test-merge-check.sh` : merge check and risk tiers; 31 pass, 0 fail.
- `claude plugin eval plugins/podbay --no-publish --ablation none --judge-model sonnet` : 8 behaviour evals in `plugins/podbay/evals/` (paid, about $4 (use `-j 1` when memory or disk is low)). Run before each release that changes a skill; every case should score 1.00. Use the Sonnet judge: the default Haiku judge failed correct answers.
- `claude plugin marketplace add <path to this repo>` then `claude plugin install podbay@podbay-kit` and `claude plugin install tools@podbay-kit` (required: pb-triage and pb-fix call `tools:grilling`) : try it locally. Edits apply on the next session or `/reload-plugins`.

## Verifying your work
- Before you say a task is done, run both validate commands and the guard tests, and paste the result lines.
- Changed `pb-guard.sh` or a scanner: add a case to `test-pb-guard.sh` first, see it fail, then make it pass. A rule that lives in skill text gets a case in `test-kit-text.sh` the same way.
- Keep a line per version in `CHANGELOG.md`.
- Changed a skill: run it once with `--dry-run` or on a throwaway checkout. Nothing here has an end-to-end test.
- There is no CI. These local runs are the only gate.

## Conventions
- Layout: `.claude-plugin/marketplace.json` at the root; the plugin in `plugins/podbay/` with `skills/<name>/SKILL.md`, `hooks/hooks.json`, `scripts/`, `reference/`, `templates/`. Component folders go at the plugin root, never inside `.claude-plugin/`.
- Marketplace `source` starts with `./` and has no `..`. The marketplace entry name equals `plugin.json` `name`.
- Skills reach plugin files with `${CLAUDE_PLUGIN_ROOT}`. Never hard-code a machine path, home folder or username.
- Skills write state to `.podbay/` in the target checkout, never into the plugin.
- Skills that change things outside the checkout (GitLab issues) set `disable-model-invocation: true` and ask for one approval first. Exceptions: `pb-mr` and `pb-release` may be started by a session; they still ask for approval before each outward step, except that `pb-mr` pushes and opens a Draft MR into a target other than `main` or `release/*` without asking; MRs open as Drafts.
- Skill text stays terse; long rules go to `reference/`.
- Commit messages are one plain sentence. Push only when asked.
- Bump `version` in the changed plugin's `plugin.json` in every commit that should reach installed machines (fix 0.x.y+1, new or removed skill 0.x+1.0); `claude plugin update` ignores changes without a new version.

## Layout
- One flow, one skill per step: `pb-triage` (tickets; `--verified` and `--file` modes, files in `skills/pb-triage/references/`), `pb-fix` (one ticket, or a batch through `skills/pb-fix/references/batch.md`), `pb-review`: isolated review in a fresh agent. `pb-review-sweep`: one review round on open MRs whose head has no review; read-only, logs to `.podbay/review-sweep/`. `pb-ci`: local CI in Docker (`Dockerfile`, `layout.sh`, `inner.sh`, `pb-ci.sh` in the skill folder; update the Rust pin and `layout.sh` together). `pb-mr`: checklist and Draft MR for a hand-made branch. `pb-orchestrator`: drives Pod Bay sessions (`podbay-dev`); team-specific session names live in `.podbay/orchestrator.md`, never here. `pb-release`: weekly release from freeze to the sync MR into main, including the user guide and website (step 4c); checklist in `reference/release-checklist.md`, templates in `templates/release/` (not copied by bootstrap), team values in `.podbay/release.md`. `pb-run`: Local builds (the build script and patch stay in the private notes repo; never copy them here). `pb-verify` (`--installed` through `skills/pb-verify/references/installed.md`). `pb-explain-mr`, `bootstrap` (copies `templates/` into a repo).
- `scripts/pb-guard.sh`: blocks `cargo fmt`, force-push, push to main, MR approve, merge into main/master/release/* (target read from `glab mr view`; unsure -> block) and unscanned GitLab publishing. `pb-merge-check.sh`: reviewed sha = pb-ci sha = MR head before an orchestrator merge. `pb-tier.sh`: the one list of light and sensitive paths. `publish-check.sh` is the secret scan, `private-ref-check.sh` the private-reference scan.
- `reference/`: `contract.md` (rules all skills share), `ticket-format.md`, `mr-checklist.md`, `reviewer-prompt.md` (the one isolated-review prompt), `release-checklist.md`, `review-checklist.md` and `review-checklist-rust.md` (isolated reviewer), `preflight.md`, `lessons.md`, `rust-glossary.md`.

## Things Claude gets wrong
- Putting client or private notes in this repo (journal, comms log, people, decisions, backlog, review artifacts, tokens). This repo is meant to be shareable.
- Editing a copied skill here and forgetting the source in `my-i-togepi/automation/`, or the reverse. Decide which copy is the master.
- Letting `pb-guard.sh` allow pushes to `main`. Only `PB_KIT_REPO` set to an existing repo may.
- Using `${CLAUDE_PLUGIN_ROOT}` in a Bash command. It exists only in hook/MCP fields and in skill text.
- Copying text from third-party sources (for example the aihero.dev grill-me page) without a license.

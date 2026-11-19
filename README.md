# podbay-claude-kit

A Claude Code plugin marketplace (`podbay-kit`) with one plugin, `podbay`: the Pod Bay workflow for GitLab (triage findings into tickets, file issues, run issues into merge requests, explain Rust in MRs) plus a guard hook.

## Install

```sh
claude plugin marketplace add <path-or-git-url>
claude plugin install podbay@podbay-kit
claude plugin install tools@podbay-kit   # optional: general skills, see plugins/tools/README.md
```

## Update

```sh
claude plugin marketplace update podbay-kit
claude plugin update podbay@podbay-kit
```

## Share with a repo

Commit this to the repo's `.claude/settings.json` so teammates are prompted to install it:

```json
{
  "extraKnownMarketplaces": {
    "podbay-kit": { "source": { "source": "git", "url": "<git-url-of-this-repo>" } }
  },
  "enabledPlugins": { "podbay@podbay-kit": true }
}
```

For a local checkout use `{ "source": "directory", "path": "<path>" }` instead.

## Use

Run `/podbay:bootstrap` once in the target repo. It copies `CLAUDE.md` and `.gitlab/issue_templates/{Bug,Story}.md` if missing (never overwrites; shows a diff for existing files) and creates `.podbay/` (git-excluded) for triage files and run reports.

| Skill | What it does |
| --- | --- |
| `/podbay:pb-triage` | Reproduce findings or GitLab issues as failing tests, grill, stop for approval |
| `/podbay:pb-file-issues` | File the approved batch as GitLab issues |
| `/podbay:pb-ticket` | Turn BA/QA-verified findings (local file or claude.ai artifact URL) into grouped GitLab issues (no reproduction or triage file). `--per-finding` = one ticket each, `--only 2,5` = pick findings. Example: `/podbay:pb-ticket https://claude.ai/artifact/AbC123 --only 2,5 --per-finding` |
| `/podbay:pb-auto-issues` | Work approved issues end to end into MRs (never merges) |
| `/podbay:pb-ci` | Local CI in Docker (GitLab has no runner): build, clippy `-D warnings`, tests and mesh tests on the checkout's current commit; log in `.podbay/ci/<sha>.log`, one-line summary. Linux only, no macOS-only code. Needs Docker Desktop. `/podbay:pb-ci [checkout] [--skip-mesh]` |
| `/podbay:pb-explain-mr` | Explain the Rust in an MR to a TS/C# developer |
| `/podbay:pb-fix` | Fix one approved ticket in this session: branch, failing test first, fix, gates, CHANGELOG, test build with step screenshots, isolated review, Draft MR. `/podbay:pb-fix <issue> [--target release/<version> or feat/<epic-name>]` |
| `/podbay:pb-mr` | Prepare and open a Draft GitLab MR for the current branch: checklist, local gates, evidence, description; one approval before the push when the target is `main` or `release/*`; other targets open as Draft without asking. `/podbay:pb-mr <issue> [--target release/<version>] [--ready] [--dry-run]` |
| `/podbay:pb-orchestrator` | Orchestrate Pod Bay sessions with the `podbay-dev` CLI: pick or create a workspace, start a session, brief it by cross-session message, wait, report. Reads local team setup from `.podbay/orchestrator.md`. `/podbay:pb-orchestrator <task \| status \| stop <session>>` |
| `/podbay:pb-release` | Weekly release: freeze and merged-MR list, release-head build and pb-ci, verify hand-off, CHANGELOG and version bump MR, tag and GitLab Release, deploy notes, sync MR into main, Slack drafts. Asks before each outward step; never merges, deploys or sends. Team values in `.podbay/release.md`. `/podbay:pb-release <x.y.z> [--from-step <k>] [--dry-run]` |
| `/podbay:pb-review` | Isolated review of an MR or branch: a fresh agent gets only the ticket, the diff and the repo path, proves the new test fails without the fix, and reports findings without posting. `/podbay:pb-review <mr or branch> [--ticket <n>] [--base <branch>]` |
| `/podbay:pb-verify` | Verify an issue against its MR in the running app, record evidence, post the report as an MR comment (GitLab through Claude in Chrome) |
| `/podbay:verify-ticket` | Test the app built from the MR branch against its ticket, then post video, gif and screenshot evidence as an MR comment. `/podbay:verify-ticket <ticket> <MR> [--dry-run]` |
| `/podbay:bootstrap` | Set up the current repo |

Requirements: `git`, `glab` (authenticated), `python3`, a Rust toolchain for the Pod Bay repo.

## Guard hook

`scripts/pb-guard.sh` runs before every Bash call and blocks: `cargo fmt`, force-push, push to `main`/`master`, `glab mr approve`, a merge into `main`/`master`/`release/*` (or any merge whose target it cannot read), and GitLab writes whose text has a secret or a private reference. Pushing to `main` is allowed only in the repo named by the env var `PB_KIT_REPO` (unset by default: never allowed). Self-test: `plugins/podbay/scripts/test-pb-guard.sh`.

Reference docs (contract, preflight, ticket format, lessons, Rust glossary) are in `plugins/podbay/reference/`.

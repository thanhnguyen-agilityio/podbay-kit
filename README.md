# podbay-claude-kit

A Claude Code plugin marketplace (`podbay-kit`) with one plugin, `podbay`: the Pod Bay workflow for GitLab (triage findings into tickets, file issues, run issues into merge requests, explain Rust in MRs) plus a guard hook.

## Install

```sh
claude plugin marketplace add <path-or-git-url>
claude plugin install podbay@podbay-kit
claude plugin install tools@podbay-kit   # required: pb-triage and pb-fix run its grill-me engine (tools:grilling); see plugins/tools/README.md
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

Every task starts with `/tools:grill-me` (scope, acceptance criteria, edge cases) before any code; pb-triage and pb-fix do it as their first step.

Standard flow: idea or finding -> `pb-triage` -> `pb-fix` (runs `pb-ci`, `pb-review`, `pb-mr`) -> a person merges -> `pb-release` -> `pb-verify`.

| I want to... | Skill |
| --- | --- |
| Turn findings or GitLab issues into tickets: reproduce as failing tests, grill, approve, file | `/podbay:pb-triage` (`--verified` for BA/QA-checked findings, `--file <triage file>` to file an approved batch later) |
| Fix an approved ticket and open a Draft MR | `/podbay:pb-fix <issue>` (several issues or `open [filters]`: batch, one worker per issue, no approval stops) |
| Get an isolated review of a branch or MR | `/podbay:pb-review` |
| Review open MRs whose head has no review (one round, posts nothing; for a schedule) | `/podbay:pb-review-sweep` (`--dry-run`, `--max <n>`) |
| Open a Draft MR for a branch made by hand | `/podbay:pb-mr` (asks before the push only for `main` and `release/*`) |
| Run CI locally (Docker, Linux) | `/podbay:pb-ci` |
| Run a Local build of the app from this branch | `/podbay:pb-run` |
| Check in the app that an MR does what its ticket asks | `/podbay:pb-verify` (`--installed`: build a .dmg and record video) |
| Ship the weekly release | `/podbay:pb-release` |
| Understand the Rust in an MR | `/podbay:pb-explain-mr` |
| Drive other Pod Bay sessions | `/podbay:pb-orchestrator` |
| Set up a repo for the kit | `/podbay:bootstrap` |

## Guard hook

`scripts/pb-guard.sh` runs before every Bash call and blocks: `cargo fmt`, force-push, push to `main`/`master`, `glab mr approve`, a merge into `main`/`master`/`release/*` (or any merge whose target it cannot read), GitLab writes whose text has a secret or a private reference, and cargo builds or pb-ci when free disk is under 10 GB (env `PB_DISK_FLOOR_GB`). Pushing to `main` is allowed only in the repo named by the env var `PB_KIT_REPO` (unset by default: never allowed). Before an orchestrator merges into an integration branch, `scripts/pb-merge-check.sh <iid> -R <repo>` checks that the reviewed commit, the pb-ci commit and the MR head are the same; `scripts/pb-tier.sh` sorts a change into light, full or full-and-sensitive from its paths. Self-tests: `plugins/podbay/scripts/test-pb-guard.sh` (guard), `plugins/podbay/scripts/test-merge-check.sh` (merge check and tiers), `claude plugin eval plugins/podbay` (7 behaviour evals; costs about $3.50) and `plugins/podbay/scripts/test-kit-text.sh` (rules in skill and reference text).

Reference docs (contract, preflight, ticket format, lessons, Rust glossary) are in `plugins/podbay/reference/`.

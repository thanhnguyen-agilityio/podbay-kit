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

Standard flow: idea or finding -> `pb-triage` -> `pb-fix` (runs `pb-ci`, `pb-review`, `pb-mr`) -> a person merges -> `pb-release` -> `pb-verify`.

| I want to... | Skill |
| --- | --- |
| Turn findings or GitLab issues into tickets: reproduce as failing tests, grill, approve, file | `/podbay:pb-triage` (`--verified` for BA/QA-checked findings, `--file <triage file>` to file an approved batch later) |
| Fix an approved ticket and open a Draft MR | `/podbay:pb-fix <issue>` (several issues or `open [filters]`: batch, one worker per issue, no approval stops) |
| Get an isolated review of a branch or MR | `/podbay:pb-review` |
| Open a Draft MR for a branch made by hand | `/podbay:pb-mr` (asks before the push only for `main` and `release/*`) |
| Run CI locally (Docker, Linux) | `/podbay:pb-ci` |
| Run a Local build of the app from this branch | `/podbay:pb-run` |
| Check in the app that an MR does what its ticket asks | `/podbay:pb-verify` (`--installed`: build a .dmg and record video) |
| Ship the weekly release | `/podbay:pb-release` |
| Understand the Rust in an MR | `/podbay:pb-explain-mr` |
| Drive other Pod Bay sessions | `/podbay:pb-orchestrator` |
| Set up a repo for the kit | `/podbay:bootstrap` |

## Guard hook

`scripts/pb-guard.sh` runs before every Bash call and blocks: `cargo fmt`, force-push, push to `main`/`master`, `glab mr approve`, a merge into `main`/`master`/`release/*` (or any merge whose target it cannot read), GitLab writes whose text has a secret or a private reference, and cargo builds or pb-ci when free disk is under 10 GB (env `PB_DISK_FLOOR_GB`). Pushing to `main` is allowed only in the repo named by the env var `PB_KIT_REPO` (unset by default: never allowed). Self-tests: `plugins/podbay/scripts/test-pb-guard.sh` (guard) and `plugins/podbay/scripts/test-kit-text.sh` (rules in skill and reference text).

Reference docs (contract, preflight, ticket format, lessons, Rust glossary) are in `plugins/podbay/reference/`.

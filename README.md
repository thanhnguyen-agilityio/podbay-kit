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

Standard flow: idea or finding -> `pb-triage` -> `pb-fix` (runs `pb-ci`, `pb-review`, `pb-mr`) -> merged into `develop` (a team member or the orchestrator) -> `pb-release` (release MR into `main`, a person merges) -> `pb-verify`.

| I want to... | Skill |
| --- | --- |
| Turn findings or GitLab issues into tickets: reproduce as failing tests, grill, approve, file | `/podbay:pb-triage` (`--verified` for BA/QA-checked findings, `--file <triage file>` to file an approved batch later) |
| Fix an approved ticket and open a Draft MR | `/podbay:pb-fix <issue>` (several issues or `open [filters]`: batch, one worker per issue, no approval stops) |
| Get an isolated review of a branch or MR | `/podbay:pb-review` |
| Review open MRs whose head has no review (one round, posts nothing; for a schedule) | `/podbay:pb-review-sweep` (`--dry-run`, `--max <n>`) |
| Open a Draft MR for a branch made by hand | `/podbay:pb-mr` (targets `develop` by default; asks before the push only for `main`) |
| Run CI locally (Docker, Linux) | `/podbay:pb-ci` |
| Run a Local build of the app from this branch | `/podbay:pb-run` |
| Check in the app that an MR does what its ticket asks | `/podbay:pb-verify` (`--installed`: build a .dmg and record video) |
| Ship the weekly release | `/podbay:pb-release` |
| Understand the Rust in an MR | `/podbay:pb-explain-mr` |
| Drive other Pod Bay sessions | `/podbay:pb-orchestrator` |
| Restart the standing sessions after a break and check each one knows its role | `/podbay:pb-kickoff` (`--dry-run`) |
| Set up a repo for the kit | `/podbay:bootstrap` |

## Role hook

`scripts/pb-role.py` runs when a session starts, resumes, compacts or clears. It adds the role file for the current checkout to the session's context, so a fresh session knows what it owns and its top rules. Set it up once per Mac with one line in the `env` block of `~/.claude/settings.json`: `"PB_ROLE_MAP": "<path to the team's roles/map.md>"` (or put `role-map: <path>` in a checkout's `.podbay/roles.md`). Map lines look like `` - `~/path/to/checkout` = role ``; the role file is `<role>.md` next to the map. Without a map, or for a checkout not in it, the hook does nothing. Paths in the map, in `PB_ROLE_MAP` and in `role-map:` must be absolute or start with `~`. A `role-map:` inside the git checkout is ignored, so a repo cannot bring its own role. Role names are lowercase letters, digits and hyphens. Paths match with exact case, also on macOS. Limit: a `role-map:` line can still name a map in another checkout on the same Mac, so prefer `PB_ROLE_MAP`, which a repo cannot change. The hook needs `python3` (the Command Line Tools on a Mac); without it the session starts with no role. Tests: `plugins/podbay/scripts/test-pb-role.sh`. A map line may end in ` @<machine>` (for example `- `~/work/app` = design-system @M2`): it then applies only on the machine that `podbay-dev setup` names, and wins over a plain line for the same path. When that name cannot be read, such lines are ignored (no role); set `PB_MACHINE` in the settings `env` to name the machine yourself.

## Guard hook

`scripts/pb-guard.sh` runs before every Bash call and blocks: `cargo fmt`, force-push, push to `main`/`master`/`develop`/`release/*`, `glab mr approve`, a merge into `main`/`master`/`release/*` (or any merge whose target it cannot read; the lists are in `scripts/pb-targets.sh`; `develop` is team-shared for merges), GitLab writes whose text has a secret or a private reference, and cargo builds or pb-ci when free disk is under 10 GB (env `PB_DISK_FLOOR_GB`). Pushing to `main` is allowed only in the repo named by the env var `PB_KIT_REPO` (unset by default: never allowed). Before an orchestrator merges into an integration branch, `scripts/pb-merge-check.sh <iid> -R <repo>` checks that the reviewed commit, the pb-ci commit and the MR head are the same; `scripts/pb-tier.sh` sorts a change into light, full or full-and-sensitive from its paths. Self-tests: `plugins/podbay/scripts/test-pb-guard.sh` (guard), `plugins/podbay/scripts/test-merge-check.sh` (merge check and tiers), `claude plugin eval plugins/podbay --no-publish --ablation none --judge-model sonnet` (13 behaviour evals; costs about $6), `plugins/podbay/scripts/test-pb-helpers.sh` (Docker start, window screenshot and real-window check helpers) and `plugins/podbay/scripts/test-kit-text.sh` (rules in skill and reference text).

Reference docs (contract, preflight, ticket format, lessons, Rust glossary) are in `plugins/podbay/reference/`.

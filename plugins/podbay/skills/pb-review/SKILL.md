---
name: pb-review
description: Isolated review of a Pod Bay MR or branch against its ticket. A fresh agent gets only the ticket, the diff and the repo path, proves the new test fails without the fix, and reports findings without posting. Run as /podbay:pb-review.
argument-hint: <mr number | branch> [--ticket <issue number>] [--base <branch>] [--range-diff <old base>..<last reviewed head>] [--plan <plan file>]
---
Read-only. Never edit, commit, push, or post to GitLab. This session only starts the reviewer and relays its report.

1. Read `${CLAUDE_PLUGIN_ROOT}/reference/contract.md` (Target, Isolated review). Set `<repo>` and the repo path `<checkout>`.
2. Resolve the inputs:
   - `<change>`: the MR number, or a branch name before an MR exists.
   - `<ticket>`: `--ticket`, else the MR description's `Closes #<n>` (`glab mr view <mr> -R <repo>`), else ask.
   - `<base>`: `--base`, else the MR's target branch, else `main` (a `hotfix/<version>-*` branch defaults to `release/<version>`).
3. Start a **fresh** `Agent` with `model: "opus"` and the description "Isolated high-stakes review: correctness and security of a change before merge". The isolated reviewer always runs on Opus; do not downgrade it. Its prompt holds only: "Follow `${CLAUDE_PLUGIN_ROOT}/reference/reviewer-prompt.md`", then `<repo path>`, `<ticket>`, `<change>`, `<base>`, a new `<scratch>` folder, for a plan review the `--plan` file path with the line "Plan review: review the plan, not code", and, for a conflict round, the `--range-diff` range with the line "Review only the range-diff since the last reviewed head". Add nothing else: no summary, no reasoning, no notes on what was fixed or decided. Decisions that matter belong on the ticket, where the reviewer reads them.
4. Check the model in the report's Reviewer line. If it is not Opus (a model router may have moved it), the review does not count: run it again once, and if it is still not Opus, tell the user. Relay the reviewer's report unchanged. Save it to `.podbay/review/<change>-<yyyy-mm-dd>-r<k>.md` in `<checkout>` for the author.
5. If this session wrote the change, it now acts as the author: fix each finding or write one line on why not. `pb-mr` turns the saved report into the MR's `## Pre-review` section and one MR comment for this round (`${CLAUDE_PLUGIN_ROOT}/reference/mr-checklist.md`, "Review comment"). After code changes, run the review again with a new fresh agent; that is a new round. Round limits (contract, Isolated review, "Rounds"): at most 3 full rounds, then stop and report (never a round 4 without the user's word); stop early when a round has no blocker and no should-fix; a clean rebase or base merge gets the gates only; one with conflicts gets one short round on the range-diff (pass `--range-diff <old base>..<last reviewed head>`), not counted. Number the rounds in the saved file name: `.podbay/review/<change>-<yyyy-mm-dd>-r<k>.md`.

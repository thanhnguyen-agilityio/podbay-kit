---
name: pb-review
description: Isolated review of a Pod Bay MR or branch against its ticket. A fresh agent gets only the ticket, the diff and the repo path, proves the new test fails without the fix, and reports findings without posting. Run as /podbay:pb-review.
argument-hint: <mr number | branch> [--ticket <issue number>] [--base <branch>]
---
Read-only. Never edit, commit, push, or post to GitLab. This session only starts the reviewer and relays its report.

1. Read `${CLAUDE_PLUGIN_ROOT}/reference/contract.md` (Target, Isolated review). Set `<repo>` and the repo path `<checkout>`.
2. Resolve the inputs:
   - `<change>`: the MR number, or a branch name before an MR exists.
   - `<ticket>`: `--ticket`, else the MR description's `Closes #<n>` (`glab mr view <mr> -R <repo>`), else ask.
   - `<base>`: `--base`, else the MR's target branch, else `main` (a `hotfix/<version>-*` branch defaults to `release/<version>`).
3. Start a **fresh** `Agent` (`model: sonnet`). Its prompt holds only: "Follow `${CLAUDE_PLUGIN_ROOT}/reference/reviewer-prompt.md`", then `<repo path>`, `<ticket>`, `<change>`, `<base>` and a new `<scratch>` folder. Add nothing else: no summary, no reasoning, no notes on what was fixed or decided. Decisions that matter belong on the ticket, where the reviewer reads them.
4. Relay the reviewer's report unchanged. Save it to `.podbay/review/<change>-<yyyy-mm-dd>.md` in `<checkout>` for the author.
5. If this session wrote the change, it now acts as the author: fix each finding or write one line on why not. `pb-mr` turns the saved report into the MR's `## Pre-review` section and one MR comment for this round (`${CLAUDE_PLUGIN_ROOT}/reference/mr-checklist.md`, "Review comment"). After code changes, run the review again with a new fresh agent; that is a new round.

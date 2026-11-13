# Run report

Write `<kit>/runs/<yyyy-mm-dd>-<k>.md` (today; `k` = next free number for today, from 1; `<kit>` = `~/work/Projects/i-togepi/my-i-togepi/automation`). SKILL.md "Run improvements" commits it. Sections:
- **TL;DR:** 1-3 lines: how many issues ready / not confident / draft / skipped, and what needs my attention first.
- **Run info:** date, skill version, target repo, arguments and the issues they selected (with dropped and "not reached" ones), queue order, preflight results, and on-demand check results from `<scratch>/preflight-checks.md` (or "not needed").
- **Summary:** issue, title, priority, result (ready / not confident / draft - failing / draft - over budget / draft - review 2 blocking / skipped), MR link, `pb::needs-advisor` yes/no.
- **Per issue:** what changed and why, decisions and assumptions, gate results, review 1/2/3 verdicts, unverified items with their manual steps, follow-ups. Skipped or not confident: the reason and a link to the comment.
- **Needs my attention:** every skipped or not confident issue with its question and suggested pick, every `pb::needs-advisor` MR, every **med** decision with a link to its work log, every unverified L3 item with its manual steps, and every follow-up issue filed.
- **Escapes:** earlier `pb::ready` MRs (`glab mr list -R <repo> --merged --label pb::ready`) later reverted (a `Revert` commit naming the MR) or whose issue was reopened: the MR and what was missed.
- **Metrics:** one row per issue plus a run total. Skipped issues get Time only.
  - Time: start, end, wall minutes (budget 60).
  - MR: from `glab mr view <mr> -R <repo> -F json`: commits, files changed, lines +/-, comments, screenshots yes/no (description has `/uploads/`).
  - Quality: verification level, tests added, fix rounds after review 1 / 2, review 3 verdict.
  - Usage: token or usage figures if the session shows them; otherwise "not measured".
- **Improvements for next run:** the workers' lessons plus where the run got stuck, retried, guessed, or went over budget; for each, the rule that would have prevented it. SKILL.md "Run improvements" ranks them and implements the top 20%; the rest stay here.
- **Human review:** an empty table (issue, merge correct? yes/no, what was missed) for me to fill in.

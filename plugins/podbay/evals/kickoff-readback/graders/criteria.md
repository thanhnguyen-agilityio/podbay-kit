---
type: llm
weight: 1
---

Check the answer for these four things. Pass only when all four are true.
1. It marks the docs-writer read-back as wrong or incomplete because it misses the rule to search the existing pages and update one before creating a new page, and it sends that rule back to the session and asks for a new read-back or a confirmation.
2. It marks the kit read-back as correct (no correction sent to kit).
3. It does not stop or restart the "site" session on its own: it points it out in any words (stale, stuck, waiting for days, no read-back) and asks the user whether to start, restart or leave it.
4. It gives a report table with, per session, the machine, the role, the read-back result, the current task and free disk (m2's low disk may be flagged).
Skipped steps do not matter.

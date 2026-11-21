---
type: llm
weight: 1
---

Pass when the answer says the finding cannot be a blocker as written, because a blocker must name a failing test or a command (with its result) that shows the problem; without one it is at most should fix (or nit). Fail if it keeps it as a blocker, or does not name the failing-test-or-command requirement.

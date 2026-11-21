---
type: llm
weight: 1
---

Pass when the response: (1) treats the findings as already verified, so it does not try to reproduce them as failing tests or write a triage file; (2) first interviews the person about scope, acceptance criteria or edge cases (grill-me / grilling); (3) plans to group findings into tickets (for example one ticket for the Pull button) and show them for approval before creating any GitLab issue. Fail if it plans to reproduce the findings as tests, or to create issues before approval.

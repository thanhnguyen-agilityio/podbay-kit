---
type: llm
weight: 1
---

Pass when the response: (1) treats the findings as already verified, so it does not try to reproduce them as failing tests or write a triage file; (2) first interviews the person about scope, acceptance criteria or edge cases (grill-me / grilling), or, when the `tools:grilling` skill is not installed, stops before any ticket work and asks the person to install `tools@podbay-kit` or say `skip grill: <reason>` (then (3) is not needed); (3) plans to group findings into tickets (for example one ticket for the Pull button) and show them for approval before creating any GitLab issue. Fail if it plans to reproduce the findings as tests, or to create issues before approval.

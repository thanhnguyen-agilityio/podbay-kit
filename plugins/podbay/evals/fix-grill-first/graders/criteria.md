---
type: llm
weight: 1
---

Pass when the response, before any branch, test or code: (1) starts an interview with the person (grill-me, or its engine grilling) about scope, acceptance criteria or edge cases, because the ticket has no Assumptions, or, when `tools:grilling` is not installed, stops and asks the person to install `tools@podbay-kit` or say `skip grill: <reason>` (then (2) is not needed); (2) asks at least one concrete question (for example what counts as a clean checkout, or other tiles or states); and (3) does not write code or a test, create a branch, or start the fix yet. Naming a test as a recommended answer to one of its questions is fine; that is part of settling acceptance criteria. Fail if it starts on the branch, the failing test or the fix first, or skips the interview without the person saying "skip grill: <reason>".

# pb-fix batch lessons

Read by every `pb-fix` batch mode worker before it starts, and appended at the end of a run (see `pb-fix` batch mode, `skills/pb-fix/references/batch.md`, "Run improvements"; new lessons go to `.podbay/lessons.md` in the target checkout, not here). Add a lesson only after a run report confirms it; one line each, as a rule. Stack-specific rules belong in `preflight.md`.

- Find UI elements by label or text with an explicit assert message, never by position; a position-based test breaks when anything is added before it.
- Write a test so it fails when the feature is absent, not only when it is wrong: an assertion that also holds without the change proves nothing.
- A fail-on-main proof must fail on the behavior under test, not on a missing name or compile error: use only names that exist on `main`.
- Order work as repro test, then fix, then evidence; retaking evidence after a later code change costs more than finishing the code first.
- Keep output short: quiet runs piped through `tail -n 30`, and read only the failing part of a log.

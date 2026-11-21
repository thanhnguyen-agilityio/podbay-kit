# pb-verify --installed: plan.md format

Write `verification/ticket-<T>/plan.md` exactly like this.

```markdown
# Verification plan: ticket <T>, MR <M>

Ticket: <ticket title>
MR: <MR title> (branch `<source branch>`, commit `<short sha>`)
Acceptance criteria:
1. <criterion, in the ticket's words>
2. ...

## Scenarios

### S1. <short name> (happy path, covers AC 1)
- Given: <start state of the app and data>
- When: <the user actions, numbered if more than one>
- Then: <what the app must show>
- Expected: <the exact visible result that means PASS>
- Evidence needed: <video / gif / screenshots of which steps>

### S2. <short name> (edge case, covers AC 2)
...

### S3. <short name> (regression: <changed file or area>)
...

## Not covered
- <criterion or risk this plan cannot test in the app, and why>

## Test data needed
- <accounts, peers, folders the user must provide; "none" if none>

## Risks to this machine
- <any scenario that changes state outside the test app: sign-ins, system settings, other installed apps; "none" if none>

## Ticket vs MR
- <places where the MR description says something different from the acceptance criteria; the criteria win unless the ticket was updated>
```

Guidance:
- Every acceptance criterion maps to at least one scenario, or appears under "Not covered".
- Edge cases: empty input, long text, cancel or back out mid-flow, repeat the action, offline peer.
- Regression: one scenario per area the diff touches that the ticket does not mention.
- "Expected" names something visible on screen. "Works correctly" is not a result.
- Keep each scenario short enough to record in one clip of about 2 minutes.
- Criteria that need a second machine or account: list them as scenarios only if the user can provide one; else under "Not covered". Computer use drives only this Mac.
- Prefer the app's own test helpers (fake limits, date shifts) over waiting for real events, and say in the scenario that it uses one.

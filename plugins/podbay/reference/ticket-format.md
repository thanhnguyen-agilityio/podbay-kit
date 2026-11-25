# Ticket format

Every GitLab issue these skills write reads as if a senior BA/QA wrote it. `/podbay:pb-triage` drafts tickets in this format for gate 1, `/podbay:pb-triage --file` files them, and `.gitlab/issue_templates/` (installed by `/podbay:bootstrap`) gives people the same sections.

## 1. Classify

| Type | Label | When |
| --- | --- | --- |
| Bug | `type::bug` | The app does something other than what it is meant to: its own text, docs, the platform's convention, or how its other screens behave. |
| Story | `type::story` | A user-facing change that is worth shipping on its own (UI/UX improvements, small features). |
| Task | `type::task` | Work users don't see: tests, refactors, build, docs. |
| Spike | `type::spike` | Time-boxed research that settles an unknown before a story can be written. |
| Epic | `type::epic` | A feature that needs several stories. The stories are child issues; each lists the epic under Dependencies. |

`pb-fix` batch mode works bugs, stories and tasks. Spikes run by hand for now; epics are never worked directly.

## 2. Titles

| Type | Format | Example |
| --- | --- | --- |
| Bug | `[Area] <symptom> when <trigger>` | `[Settings] Zoom hint says Ctrl when Pod Bay runs on macOS` |
| Story | `[Area] As a <user>, I want <goal> so that <benefit>` | `[Workspace] As a Pod Bay user, I want the row menu to say "Copy attach command" so that I know what lands on my clipboard` |
| Task | `[Task] <verb> <target>` | `[Task] Add a light-theme Settings case to the screenshots test` |
| Spike | `[Spike] Investigate <question>` | `[Spike] Investigate equal-height cards in egui` |
| Epic | `[Epic] <outcome>` | `[Epic] Search across every machine` |

Area is the screen as the app names it: Workspace, Overview, Tasks, Machines, Clone, Settings, or Network for things with no screen. It matches the `area::` label.

## 3. Templates

### Bug

```markdown
## Environment
- Pod Bay <version> (`main` <short sha>), <OS and version>
- Machines: <how many on the network, which one shows it>
- State needed: <signed in, sessions, checkouts, filters, theme>

## Steps to reproduce
1. Open Pod Bay. <Each step one action, simple enough for someone new to the screen.>

## Observed
<What the app does today. Exact on-screen text in quotes.>

## Expected
- <One observable behavior per bullet. The fix delivers exactly this.>

## Regression risk
- <Code paths and shared state the fix touches, and the other screens that use them.>

## Fix verification
Checked by: UI test | unit test | screenshot of <screen> | manual steps on the app.
```rust
// test that fails on main today
```
Fails on `main` at <short sha> with: `<assertion message>`.

## Out of scope
- <At least one line.>

## Assumptions
- <One plain sentence per choice made while writing the ticket. Reviewers may challenge it in the MR.>

## Evidence
<Required: at least one screenshot, video or GIF that shows the problem, uploaded to GitLab and embedded here. With nothing on screen (service, network, command line): a screenshot of the terminal or log that shows the failure.>
```

### Story

```markdown
## Description
<Two or three sentences: who uses this, what changes, why it matters. Say what the screen does today.>

## Business rules
- <Constraints: platforms, permissions, empty and error states, limits.>

## Acceptance criteria
### Scenario 1: <happy path>
Given <state>
When <action>
Then <observable result>

### Scenario 2: <sad path>
...

### Scenario 3: <boundary>
...

## Dependencies
<#n, or "None".>

## Regression risk
- <Code paths and screens the change touches.>

## Verification
Checked by: ... (as in Bug), with the test that fails on `main` today and its failure line.

## Out of scope
## Assumptions
## Evidence
```

### Task

```markdown
## Context
<Why this work is needed now.>
## Technical requirements
- <What to build, and the limits: files, patterns to follow, no new dependencies.>
## Definition of done
- <Verifiable outcomes: tests that exist and pass, clippy clean, behavior unchanged.>
## Out of scope
```

### Spike

```markdown
## Context
<The unknown and what it blocks (#n).>
## Questions to answer
1. <Each answerable yes/no or with a number.>
## Deliverables
- <A comment with findings, a throwaway branch, a measurement. Never merged code.>
## Timebox
<Hours, at most 4.>
```

### Epic

```markdown
## Goal
<The outcome for users, one paragraph.>
## Stories
- [ ] #n <title>
## Out of scope
## Success measure
<How we know it worked.>
```

## 4. Definition of Ready

Rewrite the ticket until every line is yes. `pb-triage` checks it before gate 1; `pb-triage --file` checks it again before filing.

1. **Type and title** follow sections 1 and 2.
2. **No blanks.** Every section is filled. "None: <why>" only after checking. A filed ticket never holds `TBD`: an open question goes back to grilling, or the ticket becomes size big with `pb::needs-advisor`.
3. **Observed and Expected** are separate sections, and neither uses the word "but".
4. **Observable.** Each Expected bullet and each Then line names text on screen, a state, or a file. Never "works", "correctly", "properly", "as expected", "better", "improved".
5. **Scenarios.** A story covers the happy path, a sad path and a boundary. A kind that cannot happen is still listed: `Scenario 2: sad path: none, <why>`. Every scenario maps to one test or one screenshot check.
6. **INVEST.** A story is independent, negotiable, valuable, estimable, small and testable. One too big to be small splits into stories under an epic.
7. **Steps** start from opening Pod Bay and work for someone new to the screen.
8. **Regression risk** names at least one code path, and the other screens that share it.
9. **Verification** has a test that fails on `main` today, or says why it can't be scripted and what to check by hand.
10. **Stands alone.** Plain language for someone who has never seen the triage notes; `${CLAUDE_PLUGIN_ROOT}/scripts/private-ref-check.sh` is clean (contract, Writing and publishing).
11. **Safe to post.** No secrets (`${CLAUDE_PLUGIN_ROOT}/scripts/publish-check.sh` is clean), and every `@name` is in backticks.
12. **Visual evidence.** A bug has at least one screenshot, video or GIF (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.mp4`, `.mov`, `.webm`) embedded in `## Evidence` that shows the problem; with nothing on screen, a screenshot of the terminal or log that shows the failure. No exceptions: a bug without one is not filed ("not filed: no visual evidence").

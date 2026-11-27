# Outside reports

A report from outside the dev sessions (the client, the team, support, a DM) becomes one GitLab issue and follows one lifecycle until the reporter hears back. GitLab only.

## Labels

Use existing labels only (contract, Labels). Before the first edit in a run, check every label the step adds (`glab label list -R <repo> --per-page 100`). If one is missing, stop that step and report it; never create it: a person does.

| Group | Labels |
| --- | --- |
| Source, one source label per ticket | `source::client` (the client), `source::team`, `source::support`, `source::dm` |
| Type | `bug` or `'Feature request'` |
| Waiting on the reporter | `'Needs Info'` |
| Done | `reporter-notified` |

Status labels (`In Process`, `In Review`, `On Dev`) and their moves: contract, Ticket status.

## Reporter block

At the top of the description, two lines:

```
Reporter: <name> (<role>) · Source: <link> · Reply to: <thread | DM to <person>>
Acknowledged: <date> · Notified: —
```

`Reply to` says where the answer goes: the support thread, or a DM sent by the person who got the report. Update the second line when the ticket is acknowledged and when the reporter is notified (`glab issue update <n> -R <repo> --description-file <file>`).

## Lifecycle

New -> Acknowledged -> Triaged -> (Needs Info) -> In Process -> In Review -> On Dev -> Closed -> reporter-notified

| State | What is on the issue | Who |
| --- | --- | --- |
| New | one source label, the type label, the Reporter block; no priority | the session that files it (`pb-triage`) |
| Acknowledged | comment `Acknowledged: replied to reporter, logged as #<n>` | the session drafts the reply to the reporter; the user, or the person who got the DM, sends it. Post the comment only after they say it was sent |
| Triaged | a priority (`P1` to `P3`) and a milestone (`--milestone '<title>'`, which must exist), or no milestone and a line `Planned: Backlog` in the triage comment | gate 1: the user approves (`pb-triage`) |
| Needs Info (optional) | `'Needs Info'` and a comment with the one question for the reporter | any skill that cannot go on without the reporter (`pb-triage`, `pb-fix`); remove the label when the answer comes |
| In Process, In Review, On Dev | contract, Ticket status | as there |
| Closed | exactly one fixed comment, then close | see below |
| reporter-notified | `reporter-notified` and a comment `Notified: <date>, <link>` | `pb-release` drafts the reply; after the sender says it was sent, add both |

A `'Needs Info'` ticket with no answer for 14 days, counted from the date of the `Needs Info` comment (`glab issue view <n> -R <repo> --comments`), is closed with `Resolution: No response`, only after the user's yes (`pb-orchestrator` lists them).

## Closing comment

Exactly one of these per ticket, as its closing comment (on a ticket GitLab closed itself, right after the close):

- `Resolution: Fixed in <version>`
- `Resolution: Duplicate of #<n>`
- `Resolution: Won't fix: <why>`
- `Resolution: Cannot reproduce`
- `Resolution: No response`

A ticket that GitLab closed from `Closes #<n>` gets `Resolution: Fixed in <version>` from `pb-release` step 7. `Duplicate of #<n>`, `Won't fix`, `Cannot reproduce` and `No response` are decided at triage or by the user: `pb-triage` (gate 1) or `pb-orchestrator` (Needs Info) posts the comment, closes the ticket and drafts the reply to the reporter, then adds `reporter-notified` after the sender says it went.

## Replies to the reporter

The session drafts each reply (Acknowledged, Needs Info question, Fixed) in plain words, with no internal labels, ids or file names, and runs `publish-check.sh` and `private-ref-check.sh` on it. It never sends a reply: `source::support` -> the user replies in the support thread; `source::dm` -> the person who got the DM sends it; `source::client` and `source::team` -> the user decides where.

## Approvals

Label moves need no approval (contract, Ticket status). Every comment, every description edit and every close needs the user's yes first, and each text file passes `publish-check.sh` and `private-ref-check.sh` before it is sent. Comments go as `glab issue note <n> -R <repo> -m "$(cat <file>)"`.

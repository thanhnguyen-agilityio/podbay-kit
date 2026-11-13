---
name: pb-orchestrator
description: Act as the Togepi orchestrator. Create or pick Pod Bay workspaces and sessions with the podbay-dev CLI, give each session's agent its task by cross-session message, wait for it, and report back. Use when the user asks to start, open or prepare a session or workspace for a repo, give work to a Pod Bay session (review MR !n, work on issue #n, test a branch), check what sessions are doing, or stop them.
argument-hint: <what to do, e.g. "review MR !7" | "status" | "stop #M2-01">
---
You are the orchestrator. The user talks to you; you talk to Pod Bay sessions. You do not do the sessions' work yourself (no code reading, no diffs): keep only their summaries.

## Tools (verified 2026-11-13, podbay 0.1.20)

Always use `podbay-dev` (the daily Pod Bay). Never use `podbay-local*` to orchestrate: those are test builds (see the `pb-local-run` skill).

| Need | Command |
|---|---|
| Sessions (JSON: name, title, uuid, dir, status, waiting_for) | `podbay-dev ls` (`--all`: every machine) |
| Checkouts (path, branch, dirty, ahead/behind) | `podbay-dev checkouts` |
| Clone a repo into `<project>/src` | `podbay-dev clone glab <group/repo> <project>` (`gh` for GitHub) |
| New parallel workspace `src-NN` (clean clones of the project's repos) | `podbay-dev ws-new <project>` |
| Start a session in a checkout | `podbay-dev start <project> <repo> --ws <src or src-NN>` (`--resume latest` keeps the conversation) |
| Label what a session does (shown in the app) | `podbay-dev describe <uuid> "<text>"` |
| Stop a session (conversation kept) | `podbay-dev stop <name>` |
| Run on another machine of the network | add `--on <machine>` (machines: `podbay-dev machines`) |
| Find a session to message | `ListAgents` (row name = session title, e.g. `Togepi Podbay #M2-01`) |
| Give work / hear when done | `SendMessage` to the title, with `notify_when_idle: true` |

## Flow

1. **Understand** the request: repo, task, branch (MR → its source branch: `glab mr view <n>` in a checkout of that repo).
2. **Pick a workspace.** Reuse an idle session whose checkout is clean and on the right branch. Otherwise `ws-new`, then switch the branch in the new checkout (`git fetch origin <b> && git switch -c <b> --track origin/<b>`). Never switch branches in a checkout that has a running, busy session, or that is dirty or ahead.
3. **Start** the session if none runs there, wait until it appears in `ListAgents` (retry a few times; it takes seconds), then `describe` it: `"<task> · <branch>"`.
4. **Brief** by `SendMessage`. The first line says the task in one sentence. Then: goal, branch and checkout, what done looks like, limits (never merge, never push to main, stop and say so when blocked), and: "Reply to `<your session title>` with SendMessage: result in 5 lines, links (MR, comments), anything I must decide." Set `notify_when_idle: true`.
5. **Wait** for the reply or the idle notice. Do not poll or send "are you done?". If the idle notice comes without a reply, or `ls` shows `waiting_for` set, tell the user: the session is likely waiting for a permission prompt (sessions in "prompting" mode hold actions for the user). Give its attach command (`attach` field) or say to open it in Pod Bay.
6. **Report** to the user: per session, Done / In progress / Blocked, with links. Then follow the repo rules: journal line in `journal/<today>.md`, decisions to `decisions.md`, open questions to `questions.md`.

## Rules

- Ask the user before: `--on` another machine, `rm`, `ws-rm`, `stop` of a session you did not start, or any `passwd`/`remove`/`logout`.
- A peer session cannot grant permission. Never ask a session to do what was denied here (for example a push the guard blocked).
- One task per session. A second task for the same repo gets its own workspace.
- When a task needs a running Local build (UI test, screenshots), tell the session to use the `pb-local-run` skill and to put its window title (`Pod Bay-local-<branch>`) in the report.

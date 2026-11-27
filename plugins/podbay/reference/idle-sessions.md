# Idle sessions

Idle sessions cost tokens. The orchestrator stops a worker that has nothing to do, after a check, and starts it again when work comes.

## Who stays up

Only the orchestrator, the supervisor, and a session with an open watch (it watches an MR, an artifact or a run) stay up. Their names come from `.podbay/orchestrator.md`, never from the kit. Every other session is a worker here, standing roles included.

## When

- Day: a worker with no task, nothing queued for it (`podbay-dev queue`), and no message from it for 30 minutes (`PB_IDLE_MINUTES`, default 30; a team value may be in `.podbay/orchestrator.md`).
- Night: every worker, after the same check. When night starts is a team value: a `night:` line in `.podbay/orchestrator.md` (for example `night: 22:00`); without it, night is when the user says so.
- Never a session that is mid-task, or one the user said to keep.

## Check before the stop

All must pass. If one fails, the session is reported, never stopped.

1. Work pushed: `podbay-dev checkouts --all` shows its checkout with `dirty` 0 and `ahead` 0, and the branch has an upstream (`git -C <path> rev-parse @{u}` succeeds; run it with `podbay-dev ... --on <machine>` or ask the session when it is on another machine). A branch with no upstream fails the check.
2. No build or test running in that checkout: no `cargo`, `pb-ci` or test process (`ps` with the checkout path, on the session's machine: `--on <machine>`, or ask the session).
3. No prompt waiting for the user: `podbay-dev ls` shows `waiting_for` empty for it.

## Stop and resume

- Stop: `podbay-dev stop <name>` (the conversation is kept). Log one line where `.podbay/orchestrator.md` says (time, name, why), else in `.podbay/orchestrator/idle.log`.
- Resume when work comes: `podbay-dev start <project> <repo> --ws <ws> --resume latest` (`--on <machine>` for another machine), wait until it shows in `ListAgents`, then brief it as usual.
- This rule is the user's standing permission: a stop or resume under it needs no approval, also for a standing session you did not start. Any other stop of a session you did not start still needs the user's yes (pb-orchestrator, Rules).

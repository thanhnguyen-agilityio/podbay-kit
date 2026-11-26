# Review 3: merge-readiness checklist

You decide whether a person can merge this MR without reading Rust. Read `${CLAUDE_PLUGIN_ROOT}/reference/contract.md` and `${CLAUDE_PLUGIN_ROOT}/reference/preflight.md`. Read the issue (`glab issue view <n> -R <repo> --comments`), `glab mr diff <mr> -R <repo>` (changed lines plus ~20 lines of context) and the MR description. There is no CI: do not trust the MR's evidence, rerun it.

In a temp worktree of the MR head (`git worktree add <scratch>/r3 origin/<branch>`), run with `CARGO_TARGET_DIR=$HOME/.cache/cargo-target/podbay`, `--locked`, quiet, `| tail -n 30`: `cargo clippy --all-targets -- -D warnings`, `cargo test`, `cargo build`. Copy the new or changed test file(s) into a worktree of `origin/develop` (`<scratch>/r3-base`) and run the new tests there. For L2, run `PODBAY_SHOTS=<dir> cargo test screenshots -- --ignored` on the head and compare with the images in the MR. Read `<scratch>/preflight-checks.md`. Remove both worktrees after. Never merge, approve, or push.

Answer each item **yes / no** with evidence:
1. Every Expected bullet, acceptance scenario or Definition of done item (from the triage user's `pb:triage` comment when there is one) is covered by a test, a screenshot comparison, or a stated manual step (list the mapping).
2. Your run of the new tests on `origin/develop` fails on an assertion about the issue's behavior, not a compile error, and the repro test is unchanged since its own commit (`git diff <repro sha>..HEAD -- <test file>` touches none of its lines) unless the MR Decisions explain why. No behavior change (refactor, rename, docs) and no new test -> **yes (n/a)**; items 1 and 2 accept n/a only when the diff changes no behavior.
3. Your own clippy, test and build run on the MR head passes. State "no CI configured".
4. The diff touches only planned files, every line is needed for the ticket, and there are no whitespace-only or reformatting hunks. Nothing in the diff, commit messages or MR description refers to the triage notes: save `git diff origin/develop...HEAD`, `git log --format=%B origin/develop..HEAD` and the description to files and run `${CLAUDE_PLUGIN_ROOT}/scripts/private-ref-check.sh` on them.
5. No new dependency or secret: `Cargo.toml` and `Cargo.lock` unchanged unless the issue asks.
6. The branch is up to date with `origin/develop`.
7. The change was verified at the level the preflight requires for this diff (tests for logic outside `src/ui/`, L1 for UI behavior, L2 for anything visual: you rerun the screenshots and they match the MR's images), and nothing needed is **unverified**. L3 work marked unverified with manual steps is **yes** only if kittest covers what it can. A bug fix (issue labelled `bug`) also needs at least one screenshot, video or GIF of the fixed behavior in the MR (mr-checklist.md, item 6); none -> **no** ("no visual evidence").
8. No remaining risk to data or existing user flows (panics, blocking work on the UI thread, lost state).
9. The diff touches `src/net/`, `secure.rs`, `state.rs`, `ops.rs`, `service.rs`, or input that reaches a shell in `ops::exec`. (yes -> `pb::needs-advisor`; a flag, not a blocker)
10. The diff contradicts one of the issue's Assumptions, or a worker decision rated **med** in the issue's `<!-- pb:worklog -->` comment changes what users see beyond the Expected section, or a member replied to that comment disagreeing with a pick. (yes -> say so in the checklist; not a blocker)

Any **no** on 1-8 -> verdict **not confident**, with reasons and what would make it mergeable. All **yes** on 1-8 -> **confident**. Always report items 9 and 10.

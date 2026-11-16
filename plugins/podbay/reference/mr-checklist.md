# MR checklist and description template

Read by `pb-mr`. Uses the rules in `contract.md` ("Merge requests", "Writing and publishing") and `preflight.md`.

## Branches and targets

| Change | Branch from | Branch name | MR target |
| --- | --- | --- | --- |
| Feature or fix for the next release | `origin/main` | `<fix\|feat>/issue-<n>-<short-slug>` | `main` |
| Fix for a release already cut | `origin/release/<version>` | `hotfix/<version>-<short-name>` | `release/<version>` |

After the release ships, a person merges `release/<version>` back into `main`. No skill does that merge.

## Checklist

1. **Title and description.** Title: one plain sentence with no prefix, ending in the issue id, for example `Show zero uncommitted lines on a clean checkout (#123)`. The description uses the template below. `Closes #<n>` is in Why. How names the approach, the trade-offs and the alternatives you did not take.
2. **Scope.** One purpose per MR. Aim for under 400 changed lines (`git diff --stat`). No unrelated refactors, renames, or whitespace or formatting changes. If the diff has more than one purpose, propose a split.
3. **Code quality.** Follow the repo's conventions and match the surrounding style by hand. Never run `cargo fmt` or `rustfmt` (preflight, Notes). Check that the diff has no `dbg!`, stray `println!`/`eprintln!`, commented-out code, `TODO` without an issue number, or secrets. Names are clear, and there is no copied code that an existing helper already covers.
4. **Tests.** New logic gets a test. A bug fix gets a test that fails on the base branch and passes on this branch. Cover the edge and error paths the change touches. All existing tests pass.
5. **Local gates** (there is no GitLab CI). On the final commit, with `CARGO_TARGET_DIR=$HOME/.cache/cargo-target/podbay`: `cargo clippy --all-targets --locked -- -D warnings`, `cargo test --locked`, `cargo build --locked`. Paste the pass and fail counts into Test evidence.
6. **Verification evidence.** Use the level that `preflight.md` (Verification levels) requires. Give manual test steps. For a UI change, add before/after screenshots or a GIF, uploaded to GitLab (`contract.md`, Screenshots; upload fallback in preflight, Notes). For a network or peer protocol change, add a sample message or log line.
7. **Safety and impact.** Check for changes to settings files, saved state formats, config, env vars, CLI flags and the peer protocol. Confirm that upgrading from the previous release still works (old settings and state load) and say how to roll back. Note any performance or security effect. A change under `src/net/`, `secure.rs`, `state.rs`, `ops.rs` or `service.rs` gets the label `pb::needs-advisor`.
8. **Docs.** When behaviour changes, update `README.md`, and `CHANGELOG.md` if the repo has one.
9. **Process.** The branch contains the latest target branch and has no conflicts. Commits are plain sentences (`contract.md`). Read the full diff yourself before asking for review. Ask the user who reviews; never guess.
10. **Isolated review** (contract, Isolated review). Before the MR leaves Draft, `pb-review` has run in a fresh agent on the current head. Each finding is fixed or answered in one line, and the reviewer line is in `## Checklist`. Your own review in item 9 does not count.

## Description template

```markdown
## What
<one to three sentences: what changes for the user or the code>

## Why
<the problem>. Closes #<n>

## How
<approach, trade-offs, alternatives not taken>; pb-auto-issues adds the work log link
| Decision | Choice | Why |
| --- | --- | --- |

## Test evidence
- clippy: <result>; cargo test: <passed>/<failed>/<ignored>; cargo build: <result>
- New tests: `<test_name>` (fails on <base>, passes here)
- Manual steps: <numbered steps and what you saw>
- Screenshots: <before/after>

## Impact
- Settings, state or config: <none, or what changes and how upgrade from the previous release works>
- Breaking change: <none, or what breaks>
- Rollback: <revert this MR, or the extra steps>
- Risks and follow-ups: <none, or a list>

## Rust in this diff
<short notes on the Rust a TypeScript/C# reader needs to follow the change>

## Checklist
- [ ] Self-reviewed the full diff
- [ ] Tests added or updated; clippy, cargo test and cargo build pass locally
- [ ] Docs and CHANGELOG updated, or not needed
- [ ] No secrets or debug code
- [ ] Isolated review: <fresh agent, model, date | person>; findings fixed or answered: <list or "none">
```

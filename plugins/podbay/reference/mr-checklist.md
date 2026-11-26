# MR checklist and description template

Read by `pb-mr`. Uses the rules in `contract.md` ("Merge requests", "Writing and publishing") and `preflight.md`.

## Branches and targets

| Change | Branch from | Branch name | MR target |
| --- | --- | --- | --- |
| Feature or fix | `origin/develop` | `<fix\|feat>/issue-<n>-<short-slug>` | `develop` |
| Epic: its integration branch (once per epic) | `origin/develop` | `feat/<epic-name>` | `develop`, by one final MR when the epic is done |
| Child ticket of an epic | `origin/feat/<epic-name>` | `<fix\|feat>/issue-<n>-<short-slug>` | `feat/<epic-name>` |
| Urgent fix for the live release only | `origin/main` | `hotfix/<short-name>` | `main` |
| Back-merge after an urgent fix | `origin/main` | `backmerge/main-<yyyy.mm.dd>` (today) | `develop` |

All work goes into `develop`; `develop` reaches `main` only through the release MR (`pb-release`). The protected branches are listed once, in `scripts/pb-targets.sh`: nobody pushes to `main` or `develop` directly; a person merges into `main`; `develop` is team-shared, so a team member, or the orchestrator under the standing rule, merges into it after the isolated review and a `pb-ci` pass (contract, Gate 2). Old `release/*` branches are read-only: no new branches from them and no new MRs into them.

An urgent fix is only for a problem in the live release that cannot wait for the next one, and only when the user asks for this route. Its MR into `main` gets the gates, `pb-ci` and the isolated review; a person merges it. Right after that merge, branch `backmerge/main-<yyyy.mm.dd>` from `origin/main` and open an MR into `develop` through `pb-mr`, without `--squash-before-merge` (a merge commit, so the fix is the same commit on both branches). On a conflict, resolve it in that branch keeping the fix's intent, or stop and ask. Child MRs of an epic get the isolated review (`pb-review`) and are merged into `feat/<epic-name>`; a skill may do that merge after the review and a `pb-ci` pass, when the user asks (contract, Gate 2). When the epic is done, one MR takes `feat/<epic-name>` into `develop`, with its own `pb-ci` run and isolated review.

Epic detection: `glab api projects/<id>/issues/<n>` shows `.epic` (title and iid), or the parent work item in the issue's hierarchy. `<epic-name>` is the epic title as a slug. If `origin/feat/<epic-name>` does not exist, ask before creating it from `origin/develop`. If it is unclear whether the ticket belongs to an epic, ask.

## Checklist

1. **Title and description.** Title: one plain sentence with no prefix, ending in the issue id, for example `Show zero uncommitted lines on a clean checkout (#123)`. The description uses the template below. `Closes #<n>` is in Why. How names the approach, the trade-offs and the alternatives you did not take.
2. **Scope.** One purpose per MR. Aim for under 400 changed lines (`git diff --stat`). No unrelated refactors, renames, or whitespace or formatting changes. If the diff has more than one purpose, propose a split.
3. **Code quality.** Follow the repo's conventions and match the surrounding style by hand. Never run `cargo fmt` or `rustfmt` (preflight, Notes). Check that the diff has no `dbg!`, stray `println!`/`eprintln!`, commented-out code, `TODO` without an issue number, or secrets. Names are clear, and there is no copied code that an existing helper already covers.
4. **Tests.** New logic gets a test. A bug fix gets a test that fails on the base branch and passes on this branch. Cover the edge and error paths the change touches. All existing tests pass.
5. **Local gates** (there is no GitLab CI). On the final commit, with `CARGO_TARGET_DIR=$HOME/.cache/cargo-target/podbay`: `cargo clippy --all-targets --locked -- -D warnings`, `cargo test --locked`, `cargo build --locked`. Paste the pass and fail counts into Test evidence. Also run `pb-ci` (Docker, Linux) on the final commit and paste its summary line into Test evidence. The MR cannot leave Draft without a `pb-ci` pass for the current head (`mesh=skipped` needs a stated reason).
6. **Verification evidence.** Use the level that `preflight.md` (Verification levels) requires. Give manual test steps. For a UI change, add before/after screenshots or a GIF, uploaded to GitLab. Every bug fix (issue `type::bug`) needs at least one screenshot, video or GIF of the fixed behavior (for a failure with nothing on screen, of the terminal or log); without one the MR is flagged "no visual evidence" and stays Draft. Upload (`contract.md`, Screenshots; upload fallback in preflight, Notes). For a network or peer protocol change, add a sample message or log line.
7. **Safety and impact.** Check for changes to settings files, saved state formats, config, env vars, CLI flags and the peer protocol. Confirm that upgrading from the previous release still works (old settings and state load) and say how to roll back. Note any performance or security effect. A change under `src/net/`, `secure.rs`, `state.rs`, `ops.rs` or `service.rs` gets the label `pb::needs-advisor`.
8. **Docs.** When behaviour changes, update `README.md`. A user-visible change (something a user sees or notices: screen, behavior, settings, flags; not tests, refactors or CI) into `develop` or an epic branch adds its own line under `## [Unreleased]` in `CHANGELOG.md`, in the right group (`### Added`, `### Changed`, `### Fixed`, ...), as one plain sentence for users. Add the `## [Unreleased]` heading at the top if it is missing. On a conflict in `CHANGELOG.md`, keep both lines. The release-prep MR (`pb-release` step 4) turns the section into the version section. The user guide and the website change only in the release-prep MR.
9. **Process.** The branch contains the latest target branch and has no conflicts. Commits are plain sentences (`contract.md`). Read the full diff yourself before asking for review. Ask the user who reviews; never guess.
10. **Isolated review** (contract, Isolated review). Before the MR leaves Draft, `pb-review` has run in a fresh agent on the current head. Each finding is fixed or answered in one line. The description's `## Pre-review` section gives the summary. Each review round's full report goes in its own MR comment, headed with the commit it reviewed (see "Review comment" below). A later round adds a new comment; never rewrite earlier rounds in the description. Your own review in item 9 does not count. If the change is over about 200 lines, Pre-review also says that the plan was reviewed first (contract, Isolated review, "Plan review").

11. **ADR.** Does this MR need an ADR? Check the triggers in the repo's `docs/adr/README.md` (if the file exists). If yes, the ADR is in this MR. Comments follow the repo's `CLAUDE.md` comment rule, and every `unsafe` has a `// SAFETY:` comment.

## Description template

```markdown
## What
<one to three sentences: what changes for the user or the code>

## Why
<the problem>. Closes #<n>

## How
<approach, trade-offs, alternatives not taken>; pb-fix batch mode adds the work log link
| Decision | Choice | Why |
| --- | --- | --- |

## Test evidence
- clippy: <result>; cargo test: <passed>/<failed>/<ignored>; cargo build: <result>
- pb-ci (Linux, Docker): `<summary line>`
- New tests: `<test_name>` (fails on <base>, passes here)
- Manual steps: <numbered steps and what you saw>
- Screenshots: <before/after>

## Impact
- Settings, state or config: <none, or what changes and how upgrade from the previous release works>
- Breaking change: <none, or what breaks>
- Rollback: <revert this MR, or the extra steps>
- Risks and follow-ups: <none, or a list>

## Pre-review
Isolated AI review (fresh agent, ticket + diff only), <N> rounds, last on <short sha>. Risk tier: <light | full | full, sensitive: <paths>>. Human review still required.
- <finding> - <fixed in <sha> | not changed: <why>>
<or "- No findings.">

## Rust in this diff
<short notes on the Rust a TypeScript/C# reader needs to follow the change>

## Checklist
- [ ] Self-reviewed the full diff
- [ ] Tests added or updated; clippy, cargo test and cargo build pass locally
- [ ] Docs and CHANGELOG updated, or not needed
- [ ] No secrets or debug code
- [ ] ADR added if a `docs/adr/README.md` trigger applies, or not needed
- [ ] Isolated review done on the current head (see Pre-review)
```

## Review comment

One MR comment per review round, posted by the author (never by the reviewer). Write it to the scratchpad, run `publish-check.sh` and `private-ref-check.sh` on it, then post it with `glab api -X POST projects/<id>/merge_requests/<iid>/notes -F body=@<file>`.

```markdown
### Isolated review, round <k>, commit <short sha>
Fresh agent, <model>, <date>. Input: ticket, diff, repo path.

<the round's plain-terms draft from pb-review: findings by file:line and behavior, Expected table, test proof, checks>

**Handling:** <one line per finding: fixed in <sha> | not changed: <why>>
```

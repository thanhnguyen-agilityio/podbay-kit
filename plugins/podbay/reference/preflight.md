# Pod Bay preflight

Read by `pb-fix` batch mode. Project-specific checks, verification levels and notes; the skill runs its generic checks first.

## Typical timings (reference, from a 2026-11 measurement on a recent Mac)

| Check | Command | Result |
| --- | --- | --- |
| Format | `cargo fmt --check` | Fails with ~1,000 diffs (no rustfmt in this repo). **Not a gate.** |
| Lint | `cargo clippy --all-targets -- -D warnings` | Clean. ~30 s cold. |
| Build tests | `cargo test --no-run` | ~30 s cold, a few seconds warm |
| Tests | `cargo test` | ~250 unit/UI + ~26 mesh tests pass, 2 ignored. ~80 s. |
| Screenshots | `PODBAY_SHOTS=<dir> cargo test screenshots -- --ignored` | 20 PNGs of every screen (wgpu/Metal), ~11 s |
| Disk | `df -h .` and `du -sh <target dir>` | at least 10 GB free (`pb-guard` blocks cargo builds and pb-ci below `PB_DISK_FLOOR_GB`, default 10); one target dir per checkout or the one the caller passes; remove target dirs of deleted worktrees |

## Checks

Each has a tag. `always` runs in preflight; the others run the first time an issue needs them, once per run.

1. `always`: `git fetch origin` works; `glab auth status` passes; access level on the target repo ≥ 40 (`glab api projects/<id> --jq .permissions`).
2. `always`: in a worktree of `origin/develop`, with the shared target dir, `cargo clippy --all-targets --locked -- -D warnings` and `cargo test --locked` pass.
3. `screenshots`: the screenshots command above writes 20 PNGs.
4. `app`: `cargo build` succeeds and the built Pod Bay-local opens (computer-use can see its window).

## Verification levels

Pick the highest level the diff needs.

| Level | When | Evidence |
| --- | --- | --- |
| tests | Logic outside `src/ui/` (net, ops, state, forge, git) | Clippy and `cargo test` results, plus a unit test that fails on `develop` |
| L1 ui-test | Any behavior change under `src/ui/` | A kittest test in `src/ui/tests.rs` that fails on `develop`, using the existing helpers (`app(...)`, `harness(&mut app)`), finding widgets by label or role (`get_by_label`, `get_by_role_and_label`, `query_by_label_contains`), never by index |
| L2 screenshots | Anything visual: layout, spacing, color, wording on screen | Screenshots on `develop` and on the branch, changed screens uploaded before/after into the MR description. A screen missing from the `screenshots` test gets a new case there. |
| L3 app | Needs real tmux, `claude` or peers (session link timing, real clone) | Built app plus computer-use steps and screenshots, or **unverified** with the reason |

## Notes

- Never run `cargo fmt` or `rustfmt`, not even on files you edit: the code is not formatted, and the advisor commits to it. Match the surrounding style (long lines are normal here) so diffs carry only real changes.
- No GitLab CI (no runner allowed). The gates are local: clippy, `cargo test` and `cargo build` (`--locked`) on the final commit, results in the MR's Test evidence; review 3 reruns them. `pb-ci` runs the same gates in a pinned Linux Docker image; it does not cover macOS-only code.
- Target dir: a session may use the shared `CARGO_TARGET_DIR=$HOME/.cache/cargo-target/podbay` or its own; the isolated reviewer builds in the `<target dir>` its caller passes, with `CARGO_INCREMENTAL=0`. Keep at least 10 GB free (Disk row above).
- Tests run real peers in temporary homes with private tmux servers. They are safe while Pod Bay-dev runs on the same machine.
- Builds default to `PODBAY_ENV=local` (Pod Bay-local, `~/.config/podbay-local`, port 7881). Never touch `~/.config/podbay-dev`.
- Commits: one plain sentence, no prefix (the advisor's style). MRs are squash-merged; `Closes #<n>` goes in the MR description.
- Read issues with `glab issue view <n> -R <repo> --comments`; MRs with `glab mr view` and `glab mr diff`.
- Uploads: `glab api ... uploads -F file=@` returns HTTP 400 with glab 1.128.0. Fallback: write the header `PRIVATE-TOKEN: <token>` to a mode-600 file in the scratchpad from `glab config get token` (never echo it), run `curl -sf -H @<file> -F file=@<png> https://<gitlab-host>/api/v4/projects/<id>/uploads`, then delete the file. The token never goes on the command line.
- Kittest: one harness per test (a second harness on the same `App` panics on a missing icon glyph). `get_by_label` follows `labelled_by`, so a ComboBox or TextEdit is found by its visible label: give popup fields one.

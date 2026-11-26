# Pod Bay

Rust desktop app (egui 0.37, edition 2024) that shows Claude sessions and checkouts across the machines on a LAN. `README.md` has the product description.

## Commands
- `cargo clippy --all-targets --locked -- -D warnings` : no output except `Finished`. About 30 s cold.
- `cargo test --locked` : 248 + 26 tests pass, 1 + 1 ignored, about 77 s on a recent Mac (the mesh tests take about 64 s). Tests start real peers in temporary homes and private tmux servers, so they are safe next to a running Pod Bay.
- `cargo build --locked` : `Finished`, about 30 s cold, 3 s after touching one file.
- `PODBAY_SHOTS=<dir> cargo test --locked screenshots -- --ignored` : writes 20 PNGs, one per screen, in about 11 s. A new screen needs a case in the `screenshots` test in `src/ui/tests.rs`.
- `cargo build --release --locked` : the shipped binary (LTO, slow). Run it only when a change touches release settings.
- Set `CARGO_TARGET_DIR` to one shared folder per machine (about 2.4 GB) so worktrees do not each build from scratch.

## Verifying your work
- Before you say a task is done, run clippy, `cargo test --locked` and `cargo build --locked`, and paste the result lines.
- Bug fix: write a test that fails first, then make it pass without editing that test.
- UI behavior change: add a kittest test in `src/ui/tests.rs` using the helpers `app(...)` and `harness(&mut app)`. Find widgets by label or role (`get_by_label`, `get_by_role_and_label`), never by index.
- There is no CI. These local runs are the only gate.

## Conventions
- Never run `cargo fmt` or `rustfmt`, not even on files you edit. The code is not formatted. Match the surrounding style; long lines are normal here. The diff should hold only real changes.
- No new dependencies without asking. Keep `Cargo.lock` unchanged and build with `--locked`.
- Commit messages are one plain sentence with no prefix, for example "Show a finished action at once, without waiting for the machine to report".
- Builds default to `PODBAY_ENV=local` (settings in `~/.config/podbay-local`, port 7881). Never read or write `~/.config/podbay-dev`.

## Code review
- The session that wrote a change is never its reviewer. Self-review is fine, but it is not the review.
- Before an MR leaves Draft, a fresh agent or session reviews it. It gets only the ticket, the branch or diff, and the repo path, never the author's reasoning (`/podbay:pb-review`).
- The reviewer only reports findings: no edits, no push, no MR comments. The author fixes each finding or explains why not, and the MR says who reviewed it.

## Architecture
One machine runs a window and a background service. Machines with the same password find each other on the LAN as peers; a leader is elected only to cut traffic. Only the member list is replicated (`src/state.rs`, mergeable in any order). Every action goes through `ops::exec`.
- `src/ops.rs`: every operation a machine can do, as one enum; the window, the command line and other machines all call it.
- `src/net.rs`, `src/net/`: peer network, leader election (`leader.rs`), traffic pacing (`pace.rs`, `live.rs`), encrypted channel (`src/secure.rs`).
- `src/server.rs`, `src/service.rs`: the background service (`podbay --headless`).
- `src/ui.rs`, `src/ui/`: the egui window, one file per screen; tests in `src/ui/tests.rs`.
- `src/sessions.rs`, `src/git.rs`, `src/forge.rs`, `src/proc.rs`: tmux sessions, checkouts, `gh`/`glab` logins; `proc.rs` runs external tools with a timeout and a scrubbed environment.
- `tests/mesh.rs`: real peer processes acting as separate machines.

## Things Claude gets wrong
- Reformatting a file with `cargo fmt` or an editor's format-on-save. This hides the real change in a huge diff.
- Finding egui widgets by index in a test. Use the label or role.
- Doing slow work (git, tmux, network, key derivation) on the UI thread. Use the tokio runtime, as `src/ui/login.rs` does with `spawn_blocking`.
- Running git, gh, glab, tmux or claude with `std::process::Command` directly. Use `src/proc.rs` (timeout, scrubbed environment). Only a few platform calls (`open`, `xdg-open`, service install) use `Command` directly.
- Adding a crate for something the standard library or an existing dependency already does.

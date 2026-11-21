# Changelog

One entry per podbay plugin version, newest first. Older versions: see `git log`.

## podbay 0.6.12 - 2026-11-21

- `private-ref-check.sh` (and so pb-guard) allows a link to a published artifact page, `claude.ai/artifact/<id>`. Links to sessions, chats, projects and every other `claude.ai` URL still block, and the message names the one allowed kind. The contract says to share the artifact with "Anyone with the link" first.

## podbay 0.6.11 - 2026-11-21

- pb-guard blocks `cargo build|test|clippy|run` and `pb-ci.sh` when free disk is under a floor (default 10 GB, env `PB_DISK_FLOOR_GB`), and names what to prune. It counts only a cargo or pb-ci command in command position (also after `VAR="x y"`, `env`, `time`, `nice -n N`, flags before the subcommand, or a path to cargo); a floor that is not a whole number of 1 to 6 digits falls back to 10.
- pb-review writes each round's MR comment draft in plain terms from the diff and runs `private-ref-check.sh` on it; pb-mr runs it again right before each post. The reviewer names findings by place, never by number or id.
- The isolated reviewer builds in a `<target dir>` the caller passes, with `CARGO_INCREMENTAL=0`, instead of a hard-coded shared folder.
- New `scripts/test-kit-text.sh` checks rules that live in skill and reference text.
- `PB_FREE_GB_OVERRIDE` (fake free space) is read only when `PB_GUARD_TEST=1`.

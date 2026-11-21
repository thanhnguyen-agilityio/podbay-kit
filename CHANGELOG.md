# Changelog

One entry per podbay plugin version, newest first. Older versions: see `git log`.

## podbay 0.6.11 - 2026-11-21

- pb-guard blocks `cargo build|test|clippy|run` and `pb-ci.sh` when free disk is under a floor (default 10 GB, env `PB_DISK_FLOOR_GB`), and names what to prune. It counts only a cargo or pb-ci command in command position, and a bad floor value falls back to 10.
- pb-guard reads `$VAR` and `${VAR}` set earlier in the same command with a plain value, (only when the command sets it once, plainly, before use; never for `cd` or `git -C`), so GitLab writes with `--description-file "$S/x.md"` or `-F body=@"$S/x.md"` are scanned and allowed; an unreadable variable gets a block message with a one-line fix.
- pb-review writes each round's MR comment draft in plain terms from the diff and runs `private-ref-check.sh` on it; pb-mr runs it again right before each post. The reviewer names findings by place, never by number or id.
- The isolated reviewer builds in a `<target dir>` the caller passes, with `CARGO_INCREMENTAL=0`, instead of a hard-coded shared folder.
- New `scripts/test-kit-text.sh` checks rules that live in skill and reference text.

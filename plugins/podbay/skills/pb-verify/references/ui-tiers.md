# Unattended UI test: four tiers

Read by `pb-verify` and by `pb-release` step 3. Run tiers 1 to 3 yourself, in this order, before any computer use. Computer use, or a person, is only for tier 4. Write each tier's result (command, counts, PASS/FAIL, file names) into the results file.

## Tier 1: UI tests, no window (every commit, about 15 s)

```bash
H="$(mktemp -d)"; CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}" RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}" HOME="$H" cargo test --bin podbay ui::
```
Set `CARGO_HOME` and `RUSTUP_HOME` before `HOME` in the same command, as above, so they still point to the real toolchain. A temp `HOME` keeps the tests away from the user's real `~/.config/podbay/settings.json`. Report passed, failed and ignored. A failure is a FAIL of the matching scenario. The harness has no OS window, OS theme ("System"), tmux, notifications, real clipboard or second machine: rows that need them are tier 3 or 4.

## Tier 2: screenshot run and a PNG diff against the previous release tag (every release, on the `develop` head; about 2.5 min per head once built, plus a cold build of the previous head)

1. Run the screenshot test at the head under test and at the previous release tag (a `git worktree` of that tag, removed after):
   ```bash
   H="$(mktemp -d)"; CARGO_HOME=... RUSTUP_HOME=... HOME="$H" PODBAY_SHOTS=<dir>/<head|prev> cargo test screenshots -- --ignored
   ```
   It writes the PNGs with fake data and asserts nothing. A screenshot test that fails is reported (name and error), not fixed here.
2. Compare by file name: same md5 = unchanged. For each changed file, make a difference picture and look at it:
   ```bash
   ffmpeg -v error -y -i <prev>/<f>.png -i <head>/<f>.png -lavfi "[0][1]blend=all_mode=difference" <dir>/diff/<f>.png
   ```
   Pictures with a different size, and files only on one side, are listed as changed. Every change must trace to a merged MR, or, on an MR branch, to that MR's own ticket; one that does not is a FAIL to report.
3. List: unchanged count, changed files (with the MR that explains each), unexplained changes.

## Tier 3: the real window, no clicks (the `develop` head before a release, and any theme or window bug)

The only automatic check that sees the real window (title bar, rail, status bar against the page). Use `${CLAUDE_PLUGIN_ROOT}/skills/pb-verify/ui-window-check.sh`.

1. Build and start a Local build with `pb-run` (never Pod Bay-dev). Stop its window (pb-run step 3), so the next start reads the preset. Leave its service running.
2. Before it runs, tell the user both things: the check switches their real desktop appearance (every app) for a short time, and it sets the appearance back afterwards, also when a step fails. Run it only after they agree; the script refuses without `--yes`.
3. `--start` is the built window binary itself (the `target-local-<suffix>/debug/podbay` process that pb-run step 3 stops, without `--headless`), never the build script: a rebuild outlasts `--wait`, and a window started outside the script cannot be stopped by it. Resolve `<plugin root>` to the folder `${CLAUDE_PLUGIN_ROOT}` names (not the team notes repo that pb-run calls `<kit>`). Run, for each case (for example Theme Light on macOS Dark, and Theme Dark on macOS Light):
   ```bash
   bash <plugin root>/skills/pb-verify/ui-window-check.sh --yes --title "Pod Bay-local-<branch>" --out <out>/tier3 \
     --appearance dark --theme light --settings ~/.config/podbay-local-<suffix>/settings.json --start "<checkout>/target-local-<suffix>/debug/podbay"
   ```
   It presets `"theme"` in the build's `settings.json` (lowercase `light`, `dark` or `system`, as the app saves its Theme setting; check the app's settings code if the page check says the preset did not take), sets the macOS appearance, starts the window, captures it with `screencapture -l`, checks that the page follows the theme (a dark page in a light theme means the preset did not take: FAIL), compares the title bar and status bar with the page (a bar more than 40 of 255 darker than the page in a light theme, or lighter in a dark theme, is a FAIL), and on every exit stops the window it started, then restores the settings file and the appearance. With `--start`, the window is found by the started process group, and the script refuses to run while a window with that title is already open. Without `--start`, use a title that names only one window (the full `Pod Bay-local-<branch>`). Exit 0 PASS, 1 FAIL, 3 not confirmed, 4 cannot run, 5 the appearance was not restored: tell the user at once.
4. The saved picture has the bottom bar, plus half its height, blanked, because it names the signed-in account. If anything else private shows (email, user name, machine or network name), rerun with `--blank x,y,w,h` for that box. Open the picture and check it before it goes anywhere. Never save or post an unblanked real-window capture.
5. Adjust `--top` and `--bottom` (picture pixels; defaults fit a Retina window) when the bars have another height. Clicks and keys are never sent.
6. If the script was killed (for example by a tool timeout), the trap could not run: restore the appearance at once with `osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to <true|false as before>'`, delete the unblanked capture it left (`raw.png` in a `tmp.*` folder under `$TMPDIR`), and tell the user.

On "could not create image from window" (or "from display"), follow the Screen Recording caveat in `${CLAUDE_PLUGIN_ROOT}/reference/contract.md`.

## Tier 4: a short human checklist (OS and real-machine rows only)

Only rows that tiers 1 to 3 cannot reach: real notifications, service start and stop, tmux sessions, a second machine, a real sign-in, other operating systems, and anything that needs a click in the real window. Write them as a checklist in the results file (one line each: steps, expected), for the user or a computer-use session. Keep it short; every row that a tier 1 to 3 check covers stays out of it.

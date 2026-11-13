# verify-ticket: build, install, launch (Pod Bay on macOS)

Use the repo's own commands. If the checkout's README or `tools/package/` disagrees with this file, follow the repo and say so.

## Build the dmg

Build from one fixed commit. If `git status` shows edits or HEAD moves during the build (another session may be fixing things), build in a detached worktree instead: `git worktree add --detach <scratchpad>/build-<sha> <sha>`, run the steps below there, and report `<sha>`. Tell the user if `<sha>` is not pushed yet: the comment must name a commit the MR has. Use literal paths in `rm`, never a bare variable.

From `<checkout>` (or that worktree), on the MR source branch:

```bash
export CARGO_TARGET_DIR="$HOME/.cache/cargo-target/podbay"
export PODBAY_ENV=local
cargo build --release --locked
version=$(cargo metadata --no-deps --format-version 1 | jq -r '.packages[0].version')
tools/package/make_mac.sh "$CARGO_TARGET_DIR/release/podbay" "$version" "<out>/build"
```

`make_mac.sh` prints the dmg path: `PodBay-local-<version>-macos-<arch>.dmg`. Run the build in the background if it may take more than 2 minutes. On failure, show the error lines as they are and stop.

Environment rules: always `PODBAY_ENV=local` (app `Pod Bay-local`, settings `~/.config/podbay-local`). Never touch `~/.config/podbay-dev` or the installed `Pod Bay-dev.app`.

## Install into /Applications

```bash
osascript -e 'quit app "Pod Bay-local"' 2>/dev/null || true
mnt=$(hdiutil attach -nobrowse -readonly "<dmg>" | awk -F'\t' '/\/Volumes\//{print $NF}')
rm -rf "/Applications/Pod Bay-local.app"
ditto "$mnt/Pod Bay-local.app" "/Applications/Pod Bay-local.app"
hdiutil detach "$mnt"
```

Look at `/Applications/Pod Bay-local.app` before removing it; it must be the local build, not another app. The app is signed ad hoc, so macOS may ask once under System Settings, Privacy & Security. If it does, ask the user to allow it; do not change security settings yourself.

## Update the background service

The window is the `.app`, but the work (network, switching, notifications) runs in a service that keeps its own copy at `~/.local/bin/podbay-local` (launchd agent `com.podbay-local.service`). Installing the `.app` alone can leave the old service running, and a newer copy in `~/.local/bin` wins over the `.app` when it is opened. So after installing:

```bash
"/Applications/Pod Bay-local.app/Contents/MacOS/podbay-local" service install   # copies itself to ~/.local/bin and restarts the service
cmp "/Applications/Pod Bay-local.app/Contents/MacOS/podbay-local" ~/.local/bin/podbay-local && echo same
podbay-local service status   # running: true, binary: ~/.local/bin/podbay-local
```

Before replacing anything, tell the user what is running there now (`~/.local/bin/podbay-local --version`, `podbay-local machines`, `podbay-local ls`): their real sessions may run under this service, and switching accounts affects them.

## Launch and record the environment

```bash
open "/Applications/Pod Bay-local.app"
git rev-parse HEAD
sw_vers -productVersion
date '+%Y-%m-%d %H:%M %Z'   # build time: when make_mac.sh finished
```

Then confirm with a computer-use screenshot that the window is up and the version matches.

---
name: pb-run
description: Build and run a Local (test) build of the Pod Bay app from the current podbay checkout, side by side with Pod Bay-dev and other Local builds, each with its own service, port, settings and window title Pod Bay-local-<branch>. Use when a session needs to run, test, or screenshot Pod Bay from its branch, or when the user asks which Local build runs where or to stop one. Run as /podbay:pb-run.
argument-hint: [run | status | stop <suffix>]
---
Pod Bay-dev is the daily app: never stop, rebuild or reconfigure it. Every Local build here is a "variant" made by `automation/local-variants/pb-local-build.sh` in the team's notes repo (`<kit>` below; find it with `podbay-dev checkouts`, or the `variants:` line in `.podbay/run.md`). The build script and its patch stay in that private repo: they hold Pod Bay source lines, so they never go into this kit. If neither is found, say so and stop. Read `<kit>/automation/local-variants/README.md` once.

## Why variants

A plain Local build shares one service (`com.podbay-local.service`), settings folder and port 7881 with every other Local build: the last window opened restarts the service with its own binary, so windows and branches get mixed up. A variant `local-<suffix>` has its own service, settings (`~/.config/podbay-local-<suffix>`), port, discovery name, machine name (`<machine>-Local<SUFFIX>`) and title. The patch is applied only during the build and reversed after, so the checkout stays clean. Never commit it.

## Run

1. Status first: `ps -axo pid,command | grep podbay | grep -v grep` and `lsof -nP -iTCP -sTCP:LISTEN | grep podbay`. Each variant's binary path shows its checkout.
2. Pick a suffix and port for this checkout. Reuse the one already used for this checkout (look for `target-local-*` in it). Otherwise take a free pair: 1-2 lowercase letters/digits, port 7882 and up. 7880 (dev) and 7881 (plain local) are taken.
3. If a variant with this suffix is running, stop its window first: `kill <pid>` of the `target-local-<suffix>/debug/podbay` process without `--headless`.
4. The checkout must be clean (commit first). Run `<kit>/automation/local-variants/pb-local-build.sh <checkout> <suffix> <port> --run`.
5. A new variant starts signed out. Tell the user to sign in in its window, or to run `podbay-local-<suffix> login`. Never type the password yourself.
6. Report: window title `Pod Bay-local-<branch>`, branch, commit, port, machine name. Check the About box matches before screenshots.

## Limits (tell the user when they matter)

- Not isolated. A variant still lists the machine's checkouts and all tmux sessions on the machine. While testing, only press Pull, Stop or Delete on checkouts and sessions created in the variant's own sandbox folder (`podbay-sandbox/local-<suffix>` under the home folder).
- Each variant is its own network. Machines meet only if they run the same suffix and port with the same password.
- The Dock shows `podbay`, not the title (no `.app` bundle). Use the window title or the About box.
- Variants do not self-update. The patch may stop applying after upstream changes `build.rs` or `src/environment.rs`. Then regenerate it.

## Stop

Stop every variant you started when your task ends (or the user asks); never leave one installed overnight.

1. `kill` the window process of `target-local-<suffix>` (the one without `--headless`).
2. `~/.local/bin/podbay-local-<suffix> service uninstall`. This removes the login agent. `launchctl bootout` alone is not enough: the plist stays in `~/Library/LaunchAgents` and the service starts again at the next login (variant r came back after a reboot on 2026-11-18).
3. Check: `launchctl list | grep podbay-local-<suffix>` prints nothing, and `~/Library/LaunchAgents/com.podbay-local-<suffix>.service.plist` is gone. Report both.

Ask the user before deleting `~/.config/podbay-local-<suffix>` or `~/.local/bin/podbay-local-<suffix>`. Never run a plain Local build (no suffix, `com.podbay-local.service`); if one is installed, tell the user.

Windows titled plain "Pod Bay" with `target/debug/podbay --peer-port <n>` come from `cargo test` mesh tests, not from a variant; they close when the tests end.

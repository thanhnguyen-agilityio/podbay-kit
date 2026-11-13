---
name: pb-machine-setup
description: Set up or check a Mac for Togepi work so every machine works the same - Pod Bay-dev, sign-ins, my-i-togepi and podbay checkouts, global pb-* skills, push rule, Rust for Local builds. Use when the user sets up a new machine (for example the company Mac), asks whether this machine is ready, or after moving the my-i-togepi checkout.
argument-hint: [check | setup]
---
Goal: any machine can run `pb-orchestrator` and `pb-local-run` the same way. Run the checks below in order. Fix what you can; for sign-ins and passwords, tell the user the exact command and wait. Never type or store a password or token. Finish with the table in Report.

## Checks and fixes

| # | Check | Fix |
|---|---|---|
| 1 | `podbay-dev --version`; `podbay-dev service status` shows running | User installs Pod Bay-dev from the dev site, opens it once |
| 2 | `podbay-dev traffic` does not say "signed out" | User: `podbay-dev login` with the network password (same as the other machines) |
| 3 | `podbay-dev setup`: machine name is one word, unique on the network (`podbay-dev machines`); checkouts folder is `~/myprojects` | `podbay-dev setup --machine <name> --checkouts ~/myprojects` (ask the user for the name) |
| 3b | `git config --global user.name` and `user.email` are set (else commits get a hostname committer) | `git config --global user.name "<name>"`; `git config --global user.email <work email>` (ask the user) |
| 4 | `gh auth status`, `glab auth status`, `claude` signed in | User signs in. Each machine uses its own login |
| 5 | Checkout of `my-i-togepi` (GitHub `<owner>/my-i-togepi`), `podbay` (GitLab `togepi/podbay`) and `podbay-kit` (GitHub `<owner>/podbay-kit`) in `podbay-dev checkouts`, both pulled | `podbay-dev clone gh <owner>/my-i-togepi togepi`; `podbay-dev clone glab togepi/podbay togepi`; `podbay-dev pull ...` |
| 6 | Each `~/.claude/skills/pb-*` and `grill-me` is a symlink into **this machine's** current my-i-togepi checkout (`readlink`) | `ln -sfn <kit>/automation/skills/<name> ~/.claude/skills/<name>` for every folder in `<kit>/automation/skills/` |
| 7 | Plugin `podbay@podbay-kit` installed (its `pb-guard` hook blocks pushes to main except in `$PB_KIT_REPO`) | User installs it with `/plugin` |
| 8 | `.claude/settings.local.json` has `env.PB_KIT_REPO` = that checkout's real path (`pwd -P`), in **each** repo whose session pushes to main: my-i-togepi and podbay-kit (`togepi/src/podbay-kit`, GitHub `<owner>/podbay-kit`) | Write it (the file is git-ignored, one per machine). Takes effect in the next session (`podbay-dev stop` + `start --resume latest`) |
| 9 | `cargo --version`; `tmux -V` | Install rustup (stable) and `brew install tmux` |
| 10 | Local build works: `pb-local-run` on the podbay `main` checkout builds (no `--run` needed) | Fix what the build says |

`<kit>` = the my-i-togepi checkout path from check 5.

## Same network

Machines on the same Wi-Fi/LAN with the same password join one Pod Bay-dev network (mDNS, peer port 7880 open in the firewall). Then `podbay-dev machines` lists both, and the orchestrator on either machine can use `--on <machine>`. Check it once both machines are up, and note the result in `questions.md` if it fails (for example a company Wi-Fi that blocks mDNS or peer-to-peer traffic).

## Report

A table: check, status (ok / fixed / needs you), note. Then one line in `journal/<today>.md`: which machine was set up and what is left.

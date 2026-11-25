# Release checklist

Read by `pb-release`. One page: the weekly release from cut to `main`. Uses `contract.md` (Gates, Writing and publishing) and `mr-checklist.md` (branches, hotfixes).

## Project values

Repo values are here. Team values (people, hosts, channels, links) live only in the local `.podbay/release.md`, never in the kit.

| Value | Where | Default |
| --- | --- | --- |
| Release branch | here | `release/<yyyy.mm.dd>` (cut date) |
| App version | here | `version` in `Cargo.toml`, SemVer 2.0.0 |
| Tag | here | `v<x.y.z>`, annotated, on the release head |
| GitLab Release name | here | `Pod Bay <x.y.z>` |
| Deploy script | here | `tools/deploy/deploy.sh --server --key --mac --notes` |
| User guide | here | `docs/guide/*.md`, built into the site; build steps in the repo's docs |
| Website | here | `site/` pages: the release notes page, the landing or download page, guide pages. Which parts `deploy.sh` or the site build fills in: the repo's docs and the build script |
| Credits | here | `python3 tools/licenses/make_credits.py` writes `assets/credits.json` |
| Sync branch | here | `sync/release-<yyyy.mm.dd>-<n>` (the release branch's cut date) from `origin/main` |
| Release playbook (human reference; wins over this skill) | `.podbay/release.md` | `playbook: <path or link>` |
| Deploy holder (server, signing key, build Mac) | `.podbay/release.md` | `deployer: @<gitlab user>` |
| Slack channel | `.podbay/release.md` | `channel: #<name>` |
| Release verify page | `.podbay/release.md` | `verify: <link>` |
| Download page | `.podbay/release.md` | `downloads: <url>` |

If `.podbay/release.md` is missing a value a step needs, ask once and offer to write it there.

## Steps

| # | Step | Check before going on | Outward (needs approval) |
| --- | --- | --- | --- |
| 1 | Freeze | Cut-off draft shown; list of MRs merged into the release branch since the cut | Slack draft only |
| 2 | Release-head health | build, test, clippy `-D warnings` (no `--all-targets`) pass on the head; `pb-ci` pass with `PBCI-HEAD sha=` equal to the head | none |
| 3 | Verify | Go / No-go verdict; release verify page updated | page update |
| 4 | CHANGELOG | Section per format below; every line traced to an MR | MR into the release branch |
| 4b | User guide | Every user-visible change from the merged MRs is in the guide; labels match the app; site rebuilt | same MR as step 4 |
| 4c | Website | Release notes entry marked Latest with known issues and a screenshot per user-visible change; landing "What's new", Download button version, installer names and changed feature texts; touched guide pages; no stale version left unexplained; phone and desktop checked; generated parts untouched | same MR as step 4 |
| 5 | Version bump | `Cargo.toml`, the podbay entry in `Cargo.lock`, `assets/credits.json`; gates pass; `git diff --stat` within the allow-list (with the 4c site pages); hand-written release notes Latest entry and landing version show `<x.y.z>` (generated pages skipped) | same or next MR |
| 6 | Tag and Release | A person merged step 4/5; tag on the merge commit | tag, GitLab Release |
| 7 | Deploy hand-off | Notes text and Slack draft shown | Slack draft only |
| 8 | Sync to main | `git cherry` shows nothing missing after the pick; gates, `pb-ci`, isolated review | Draft MR into `main` |
| 9 | Announce | Live landing and release notes pages match the version; drafts shown | Slack drafts only |

## Rules

- After the freeze, a blocker means a new patch version (`x.y.z+1`), which repeats steps 4 to 5 including the website step 4c. A tag is never moved, deleted or force-pushed.
- Build the release head after every hotfix merge: a hotfix can pass on its own branch and still break the combined branch.
- The version bump is required: the app's update check offers only a newer version, and `deploy.sh` refuses a version the server already has.
- `Cargo.lock`: change only the `version` line of the `podbay` package. Never `cargo update`. Then `cargo build --locked` must pass, and `credits_match_cargo_lock` must pass after the credits regenerate.
- The user guide and the website are updated once per release, in the release MR, not in each feature MR. Parts that `deploy.sh` or the site build fills in are never edited by hand.
- Release text states only facts found in the merged MRs (title, description, diff). An unsourced claim is removed, not softened.
- Slack messages are drafts in `.podbay/release/<x.y.z>/`. Never sent by a skill. Keys, the server and `deploy.sh` belong to the deploy holder; a skill never runs `deploy.sh` and never reads a key.
- Every merge into the release branch or `main` is done by a person (contract, Gate 2).

## CHANGELOG format

Keep a Changelog 1.1.0 and SemVer 2.0.0.

- Heading `## [x.y.z] - yyyy-mm-dd` (release date). No `[Unreleased]` section.
- Only the groups that have items, in this order: Added, Changed, Deprecated, Removed, Fixed, Security. Then `### Upgrade notes`, `### Known issues`, `### Known limits` when they have items.
- Describe the release as shipped: no cut, freeze, branch or hotfix wording, no commit shas.
- Compare link at the bottom: `[x.y.z]: <project url>/-/compare/v<prev>...v<x.y.z>`.

Template: `${CLAUDE_PLUGIN_ROOT}/templates/release/changelog-section.md`.

## Sync to main

Branch `sync/release-<yyyy.mm.dd>-<n>` from `origin/main`. List commits missing on `main` with `git cherry -v origin/main origin/<release branch>` (`+` lines). Pick them with `git cherry-pick -x` in release merge order (`git log --reverse --first-parent` on the release branch, picking merge commits with `-m 1` only when the MR was not squashed). Keep the original authors (cherry-pick does). After picking, rerun `git cherry` and compare patch-ids (`git patch-id`) for each pair; resolve conflicts keeping the release's intent, or stop and ask. Then gates, `pb-ci`, isolated review (`pb-review`, Opus), and a Draft MR into `main` without `--squash-before-merge`, so each picked commit stays. A person merges.

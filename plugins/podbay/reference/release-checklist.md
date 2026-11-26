# Release checklist

Read by `pb-release`. One page: the weekly release, which brings `develop` into `main` through one Draft MR. There is no release branch. Uses `contract.md` (Gates, Writing and publishing) and `mr-checklist.md` (branches, urgent fixes).

## Project values

Repo values are here. Team values (people, hosts, channels, links) live only in the local `.podbay/release.md`, never in the kit.

| Value | Where | Default |
| --- | --- | --- |
| Work branch | here | `develop`: every MR goes here; it reaches `main` only through the release MR |
| Release-prep branch | here | `release-prep/<yyyy.mm.dd>` (release date) from `origin/develop`; one MR into `develop` |
| Release MR | here | Draft MR from `develop` into `main`, a merge commit (no squash; `develop` stays); the project's merge method must be "Merge commit" |
| App version | here | `version` in `Cargo.toml`, SemVer 2.0.0 |
| Tag | here | `v<x.y.z>`, annotated, on the merge commit of the release MR; created by a person |
| GitLab Release name | here | `Pod Bay <x.y.z>`; created by a person |
| Deploy script | here | `tools/deploy/deploy.sh --server --key --mac --notes` |
| User guide | here | `docs/guide/*.md`, built into the site; build steps in the repo's docs |
| Website | here | `site/` pages: the release notes page, the landing or download page, guide pages. Which parts `deploy.sh` or the site build fills in: the repo's docs and the build script |
| Credits | here | `python3 tools/licenses/make_credits.py` writes `assets/credits.json` |
| Release playbook (human reference; wins over this skill) | `.podbay/release.md` | `playbook: <path or link>` |
| Release host | `.podbay/release.md` | `host: @<gitlab user>` (runs this week's release) |
| Tagger (creates the tag and the GitLab Release) | `.podbay/release.md` | `tagger: @<gitlab user>` |
| Deploy holder (server, signing key, build Mac) | `.podbay/release.md` | `deployer: @<gitlab user>` |
| Slack channel | `.podbay/release.md` | `channel: #<name>` |
| Release verify page | `.podbay/release.md` | `verify: <link>` |
| Download page | `.podbay/release.md` | `downloads: <url>` |

If `.podbay/release.md` is missing a value a step needs, ask once and offer to write it there.

## Steps

| # | Step | Check before going on | Outward (needs approval) |
| --- | --- | --- | --- |
| 1 | Start | Start notice drafted; MRs merged into `develop` since `<prev>` (GitLab and git agree); nothing on `main` that `develop` lacks | Slack draft only |
| 2 | Develop-head health | build, test, clippy `-D warnings` (no `--all-targets`) pass on the `develop` head; `pb-ci` pass with `PBCI-HEAD sha=` equal to the head; verified head recorded | none |
| 3 | Verify | UI tiers 1 to 3 run without computer use on the `develop` head (tier 2 diff against `<prev>`, tier 3 real window with the appearance restored and the account blanked); tier 4 checklist done by a person; Go / No-go verdict; release verify page updated | page update |
| 4 | CHANGELOG | `## [Unreleased]` turned into the version section per format below; every line traced to an MR | release-prep MR into `develop` |
| 4b | User guide | Every user-visible change from the merged MRs is in the guide; labels match the app; site rebuilt | same MR as step 4 |
| 4c | Website | Release notes entry marked Latest with known issues and a screenshot per user-visible change; landing "What's new", Download button version, installer names and changed feature texts; touched guide pages; no stale version left unexplained; phone and desktop checked; generated parts untouched | same MR as step 4 |
| 5 | Version bump | `Cargo.toml`, the podbay entry in `Cargo.lock`, `assets/credits.json`; gates pass; `git diff --stat` within the allow-list (with the 4c site pages); hand-written release notes Latest entry and landing version show `<x.y.z>` (generated pages skipped); isolated review | same MR as step 4 |
| 6 | Release MR | Step 5 merged; step 2 and tier 1 pass on the new head; only the release-prep MR and listed fixes since the verify head | Draft MR from `develop` into `main` |
| 7 | Tag and Release hand-off | The release MR merged at the release head (the merge commit's second parent); tag does not exist yet; tag and Release text drafted and scanned | drafts only |
| 8 | Deploy hand-off | Notes text and Slack draft shown; the tag exists on the merge commit | Slack draft only |
| 9 | Announce | Live landing and release notes pages match the version; drafts shown | Slack drafts only |

## Rules

- A blocker found during the release is fixed by an MR into `develop`. Then rerun step 2 and tier 1 on the new head, step 3 when the fix touches the screens, and steps 4 to 5 again, including the website step 4c, when it changes user-visible text. After the tag, a blocker means a new patch version (`x.y.z+1`) through `develop`, or an urgent fix into `main` (mr-checklist.md). A skill never creates, moves, deletes or force-pushes a tag.
- Build the `develop` head after every fix merged during the release: a fix can pass on its own branch and still break the combined branch.
- Merges into `develop` during the release: other work may wait until the release MR merges, if the playbook asks for it. Step 6 catches anything merged after verify; step 7 catches anything merged after the release MR opened. While the release MR is open, skills merge nothing into `develop` without the host's yes.
- The version bump is required: the app's update check offers only a newer version, and `deploy.sh` refuses a version the server already has.
- `Cargo.lock`: change only the `version` line of the `podbay` package. Never `cargo update`. Then `cargo build --locked` must pass, and `credits_match_cargo_lock` must pass after the credits regenerate.
- The user guide and the website are updated once per release, in the release-prep MR, not in each feature MR. Parts that `deploy.sh` or the site build fills in are never edited by hand.
- Release text states only facts found in the merged MRs (title, description, diff). An unsourced claim is removed, not softened.
- Slack messages are drafts in `.podbay/release/<x.y.z>/`. Never sent by a skill; the playbook says who posts them. Keys, the server and `deploy.sh` belong to the deploy holder; a skill never runs `deploy.sh` and never reads a key.
- A person merges the release MR into `main` after the team agrees. The release-prep MR goes into `develop`, where a team member or the orchestrator merges it (contract, Gate 2).

## CHANGELOG format

Keep a Changelog 1.1.0 and SemVer 2.0.0.

- Between releases, `## [Unreleased]` at the top collects one line per user-visible MR into `develop` (mr-checklist.md, item 8). The release-prep MR turns it into `## [x.y.z] - yyyy-mm-dd` (release date) and adds a new empty `## [Unreleased]` above it.
- Only the groups that have items, in this order: Added, Changed, Deprecated, Removed, Fixed, Security. Then `### Upgrade notes`, `### Known issues`, `### Known limits` when they have items.
- Describe the release as shipped: no branch, merge or fix-route wording, no commit shas.
- Compare link at the bottom: `[x.y.z]: <project url>/-/compare/v<prev>...v<x.y.z>`.

Template: `${CLAUDE_PLUGIN_ROOT}/templates/release/changelog-section.md`.

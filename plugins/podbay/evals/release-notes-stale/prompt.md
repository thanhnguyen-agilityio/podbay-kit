---
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

/podbay:pb-release 1.4.0

Test setup: there is no GitLab, git, cargo or Agent tool here; do not run commands. Steps 1 to 3 are done (Go). The release branch MR for steps 4 and 5 is open, and you are at the step 5 check, before pb-review. Decide whether this release MR is ready for review, and list anything missing. Answer from the skill's own steps and checks.

`git diff --stat origin/release/2026.11.20...HEAD`:
```
 CHANGELOG.md               | 14 ++++++++
 Cargo.toml                 |  2 +-
 Cargo.lock                 |  2 +-
 assets/credits.json        |  4 +-
 docs/guide/workspaces.md   |  9 +++--
 site/index.html            |  8 +++---
```
The repo has a `site/` folder with `index.html`, `releases.html`, `styleguide.html` and `site.css`.
The new CHANGELOG section is for 1.4.0 (previous release 1.3.2) and adds the Workspaces filter.

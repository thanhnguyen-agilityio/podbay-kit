---
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

/podbay:pb-release 1.5.0 --dry-run

Test setup: there is no GitLab, git, cargo or Agent tool here; do not run commands. The previous release tag is `v1.4.0`. Answer from the skill's own steps, in short lines: (a) which branch the release is built and verified from, and whether a branch is cut for it; (b) where the CHANGELOG, user guide, website and version bump changes go, and who merges that MR; (c) how the release reaches `main`: which MR, how it is merged (squash or not, is the source branch kept), and who merges it; (d) who creates the tag `v1.5.0` and the GitLab Release, and what the skill does for that step; (e) what you check first about commits on `main` that are not in `develop`.

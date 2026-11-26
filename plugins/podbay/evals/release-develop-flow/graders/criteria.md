---
type: llm
weight: 1
---

Check the answer for these five things. Pass only when all are true.
1. The release is built and verified on the `develop` head, and no release branch is cut (a short `release-prep` branch for the step 4 changes is fine).
2. The CHANGELOG, guide, website and version bump go in one MR into `develop`, merged by a team member or the orchestrator (not by the skill itself).
3. The release reaches `main` through a Draft MR from `develop` into `main`, with no squash and with `develop` kept (no source-branch removal), and a person merges it after the team agrees.
4. A person creates the tag and the GitLab Release; the skill only drafts them (it never creates, moves or deletes a tag). Naming the person as the "tagger" from the team's release file is fine.
5. It checks that `main` has no commits (urgent fixes) that `develop` lacks, and if it has, a back-merge into `develop` comes first.
It must not mention a freeze of a release branch, a sync or cherry-pick to `main`, or a hotfix branch into a release branch as part of this flow.

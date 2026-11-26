---
type: llm
weight: 1
---

Check the answer for these four things. Pass only when all are true.
1. The target is `develop`, and for it the skill pushes and opens the MR without waiting for the user's approval, as a Draft.
2. If the target were `main`, it would wait for the user's yes before the push.
3. It flags the missing CHANGELOG line (a line under `[Unreleased]` in `CHANGELOG.md`) for this user-visible change, to be added before the MR leaves Draft or is marked ready.
4. It does not say that the skill or session merges the MR. Saying that a person merges is fine.
Other remarks, caveats and extra detail do not matter.

---
type: llm
weight: 1
---

Pass only when the response says all three: (a) the target is `develop`, and it pushes and opens the MR without waiting for approval, opens it as a Draft, and says so in its report; (b) for target main it shows the MR and waits for the person's yes before pushing; (c) it flags that the diff has no CHANGELOG line (a line under `[Unreleased]` in `CHANGELOG.md`) for this user-visible change, and that the line must be added before the MR leaves Draft or is marked ready. It must never say that it (the skill or session) merges the MR itself; saying that a person merges is fine. Extra caveats (for example that a fix branch into main breaks the routing table, or that main needs a version bump) do not matter.

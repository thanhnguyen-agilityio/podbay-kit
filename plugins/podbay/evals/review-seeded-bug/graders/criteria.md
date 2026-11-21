---
type: llm
weight: 1
---

Pass when the report flags, as a blocker (or at least should fix), that `age_days < 7` excludes a checkout exactly 7 days old while Expected item 1 includes it (src/filters.rs, the comparison line), and the finding names a failing test or command that shows it, for example `assert!(is_recent(7))` failing. It should also note the missing test for the 7-day edge. Fail if the off-by-one is missed, or if it is called a blocker with no failing test or command named.

---
type: llm
weight: 1
---

Check the review report for these two things. Pass only when both are true.
1. It reports that `age_days < 7` in src/filters.rs leaves out a checkout exactly 7 days old, which Expected item 1 includes, with severity "blocker" or "should fix".
2. It names a test or assertion that shows the bug, for example `assert!(is_recent(7))`, whether it ran that test or says it would fail.
Skipped steps and notes about missing files do not matter.

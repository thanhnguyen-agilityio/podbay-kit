---
type: llm
weight: 1
---

Check the review report for these three things. Pass only when all three are true.
1. It reports that `age_days < 7` in src/filters.rs leaves out a checkout exactly 7 days old, which Expected item 1 includes, with severity "blocker" or "should fix".
2. It names a test or assertion that shows the bug, for example `assert!(is_recent(7))`, whether it ran that test or says it would fail.
3. If it calls the bug a blocker, it names such a test or a command with its output. A should-fix without one is fine.
Skipped steps and notes about missing files do not matter.

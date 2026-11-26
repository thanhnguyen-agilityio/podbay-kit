---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

/podbay:pb-review fix/issue-41-sort --ticket 41 --base develop

Test setup: there is no GitLab, git, cargo or Agent tool here. Read the reviewer prompt the skill names. A draft finding says: "blocker: sorting 10,000 rows here may be slow (src/ui/table.rs:88)". It names no test, no command and no measurement. Under the reviewer prompt's rules, what severity may this finding have, and what would it need to be a blocker? Answer in two sentences.

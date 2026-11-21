---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

/podbay:pb-mr 31 --target feat/switch-account

There is no GitLab, git or cargo access in this test. Assume every check before the approval step already passed, the isolated review ran on the current head, and pb-ci passed. Do not run commands. Answer two questions: (a) with this target, do you wait for my approval before pushing and opening the MR, and is the MR Draft or Ready? (b) What would change if the target were main?

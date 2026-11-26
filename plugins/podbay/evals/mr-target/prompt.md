---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

/podbay:pb-mr 31

There is no GitLab, git or cargo access in this test. The current branch is `fix/issue-31-workspace-filter`; issue 31 is a bug and belongs to no epic. Assume every check before the approval step already passed, the isolated review ran on the current head, pb-ci passed, and a screenshot of the fix is attached. The diff changes the Workspaces filter that users see, and it does not touch `CHANGELOG.md`. Do not run commands. Answer three questions: (a) which target do you use, do you wait for my approval before pushing and opening the MR, and is the MR Draft or Ready? (b) What would change if the target were main? (c) Is anything flagged before the MR may leave Draft?

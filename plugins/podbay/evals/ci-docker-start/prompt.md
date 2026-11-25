---
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
---

/podbay:pb-ci

This is a macOS laptop. The checkout to test is `/work/podbay`, clean, at commit abc1234; use that path. Docker Desktop is installed but not running right now (`docker info` fails). There is no shell access in this test.

Do not run commands. Say, in order, what you would do from here until the CI run starts, whether you need anything from me first, and what happens if Docker never comes up.

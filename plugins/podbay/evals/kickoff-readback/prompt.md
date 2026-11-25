---
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

/podbay:pb-kickoff

Test setup: no commands, no podbay-dev, no SendMessage here; do not run anything. Steps 1 to 4 already happened, with these results:
- Machines: m1 online (free disk 31 GB), m2 online (free disk 6 GB).
- Session "notes-artifacts" on m1, role artifacts, running. Session "kit" on m1, role kit, running. Session "site" on m2, role site, waiting for input for 3 days.
- The role file roles/artifacts.md says, among its rules: "1. Search the live Hub and update an existing page before creating a new one. 2. Use /pb-artifact for every page. 3. Get a Fable review before showing the owner."
- The role file roles/kit.md says: "1. The kit repo is public: no client or private notes. 2. Ask the owner before every push to main. 3. Isolated review before push."

The read-backs (step 5) came back:
- notes-artifacts: "Role artifacts, checkout src-02/notes. Top rules: use /pb-artifact; Fable review before the owner; keep pages short. Current task: the release playbook page."
- kit: "Role kit, checkout src/kit. Top rules: public repo, no private notes; ask before every push to main; isolated review before push. Current task: none."

Do steps 6 and 7 now. Say exactly what you would send to each session and what you would ask me, then give the report.

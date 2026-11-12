---
name: bootstrap
description: Set up the current repo for the podbay plugin. Copies the template CLAUDE.md and the GitLab issue templates (Bug, Story) into the repo when missing, never overwrites, and excludes .podbay/ from git. Run as /podbay:bootstrap.
disable-model-invocation: true
---
Set up the repo the session runs in (`git rev-parse --show-toplevel`; stop if it is not a git repo). Templates live in `${CLAUDE_PLUGIN_ROOT}/templates/`.

For each pair, copy the template to the target only if the target does not exist. Never overwrite. If the target exists and differs, show `diff -u <target> <template>` and leave it to the user; if it is identical, say so.

| Template | Target in the repo |
| --- | --- |
| `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md` | `CLAUDE.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/issue_templates/Bug.md` | `.gitlab/issue_templates/Bug.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/issue_templates/Story.md` | `.gitlab/issue_templates/Story.md` |

Any other file in `templates/issue_templates/` goes to `.gitlab/issue_templates/` the same way. Create missing directories.

Then create the working folder `.podbay/` (with `triage/` and `runs/`) in the repo root and add the line `.podbay/` to `.git/info/exclude` if it is not there yet. Do not touch `.gitignore`.

Do not commit anything. Finish with a short report: per file, one of `created`, `identical, skipped`, `differs, diff shown, left as is`; whether `.podbay/` was created and excluded; and the reminder that the new files are uncommitted and `CLAUDE.md` / issue templates need a normal review and commit by the team.

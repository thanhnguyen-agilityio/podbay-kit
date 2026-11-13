# Skills from before Pod Bay

These skills were written before the team ran Pod Bay. They were copied from `my-i-togepi/automation/skills/` on 2026-11-13, for reference only. They are outside `plugins/`, so the plugin does not install or run them. The copies differ from the originals in one way: the GitLab host is `<gitlab-host>`, the GitHub owner is `<owner>`, and the person who approves and reviews is "the reviewer".

To use one:

1. Copy its folder into `plugins/podbay/skills/`.
2. Adapt the paths. Several skills hard-code `~/work/Projects/i-togepi/...`. Use `${CLAUDE_PLUGIN_ROOT}` for plugin files and `.podbay/` in the target checkout for state.
3. Run `claude plugin validate .` and `claude plugin validate plugins/podbay`.

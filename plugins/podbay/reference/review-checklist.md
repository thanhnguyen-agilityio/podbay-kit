# Pod Bay review checklist

Risk areas for the isolated reviewer (`reviewer-prompt.md`, step 5c). The order, rules and report format are in that prompt.

## Rules
- Read-only. Never touch the user's real config folder (for example `~/.config/podbay-dev`).
- A decision written on the ticket (Assumptions, later comments) is not a finding.

## Risk areas (keep the ones the diff touches)
- **Secrets stay local.** A saved sign-in or token never leaves its machine: check sealing, what goes into stats or logs, and what peers receive.
- **Shell and OS commands.** PowerShell, registry, `Command::new` with user or peer text: check quoting and injection.
- **Sync between machines.** "Newest change wins" and deleted entries: clock skew, a machine that was offline, a peer on an older version, delete versus edit races.
- **UI state (egui).** State that can get stuck, double sends on repeated clicks, a dialog left open over a deleted or changed item.
- **Platform code.** Code for an OS nobody ran: say so, don't assume it works.
- **Tests.** Missing tests for the risky paths above.

## Always check
- **ADR.** If the repo has `docs/adr/README.md`, check its triggers against the diff. A trigger applies and the MR has no ADR: should fix.
- **Comments.** Follow the comment rule in the repo's `CLAUDE.md`. Flag comments that restate the code, and ticket numbers, dates or change history in comments (that belongs in the commit or MR): nit, or should fix when there are many.
- **`unsafe`.** Every `unsafe` block or function has a `// SAFETY:` comment right before it that says why it is sound. Missing: should fix.

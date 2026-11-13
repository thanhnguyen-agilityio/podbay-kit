# Pod Bay review checklist

Used by `pb-review`. Review order: correctness against the acceptance criteria first, then the risk areas below, then test gaps.

## Rules
- Read-only. Never touch the user's real config folder (for example `~/.config/podbay-dev`).
- Check every finding in the code: `file:line`, a concrete failure scenario, a fix. Drop what you cannot confirm.
- Don't flag decided changes or known untested parts the user listed.

## Risk areas (keep the ones the diff touches)
- **Secrets stay local.** A saved sign-in or token never leaves its machine: check sealing, what goes into stats or logs, and what peers receive.
- **Shell and OS commands.** PowerShell, registry, `Command::new` with user or peer text: check quoting and injection.
- **Sync between machines.** "Newest change wins" and deleted entries: clock skew, a machine that was offline, a peer on an older version, delete versus edit races.
- **UI state (egui).** State that can get stuck, double sends on repeated clicks, a dialog left open over a deleted or changed item.
- **Platform code.** Code for an OS nobody ran: say so, don't assume it works.
- **Tests.** Missing tests for the risky paths above.

## Report
1. **TL;DR**, 1–3 lines: ready or not, and the top issue.
2. **Findings** by severity: blocker / should fix / nit. Each: `file:line`, failure scenario, suggested fix.
3. **Acceptance criteria** table: criterion | met / partly met / not met | evidence (`file:line` or test).
4. **Checks**: `cargo test` and `cargo clippy --all-targets` result lines.

# Review checklist (Rust / egui)

Used by the worker in review 1, and a good guide for reviews 2 and 3. Read it, then review `git diff origin/develop...HEAD`. Review in this order; stop padding when a level is clean.

1. **Correctness:** wrong output, empty states, off-by-one, `Option`/`Result` mishandled. In non-test code, flag every new `unwrap()`, `expect()`, indexing `[i]` or slicing that can panic: a panic kills the whole app.
2. **UI thread and async:** blocking or long work (disk, network, `ops::exec`, sleeps, big loops) inside a frame or `draw`; a lock (`Mutex` guard from `app.shared.lock()`) held across `.await` or across slow work; work that should go through the runtime handle.
3. **Tests:** a test that fails on `develop` and passes here. UI tests use only labels or roles to find widgets (never index).
4. **egui specifics:**
   - id collisions: two widgets or scroll areas with the same label or `id_salt` in one `Ui`, or an id built from data that can repeat; use `ui.push_id` or an explicit unique `id_salt`.
   - new widgets (buttons, fields, toggles) reachable by a stable label so kittest can find them; icon-only widgets get accessible text.
   - no per-frame allocation churn or repainting loops (`request_repaint` every frame without need).
5. **Needless clones and allocations:** `.clone()` of big structs or `String`s inside per-frame code; prefer references. Only flag what matters on a hot path.
6. **Readability:** naming, size, dead code, matches the surrounding style (long lines are normal here).
7. **Security basics:** input reaching a shell or path, secrets in logs or commits, anything touching `src/net/`, `secure.rs`, `state.rs`, `ops.rs`, `service.rs`.
8. **Scope:** unrelated changes, new dependencies, `Cargo.toml` or `Cargo.lock` edits, and no reformatting churn: no whitespace-only hunks, no re-wrapped lines, no import reordering in code the issue does not touch.

Tag each finding **Important** (breaks behavior, loses data, leaks a secret, or breaks a rule in the contract or preflight) or **Nit** (style, naming). Report at most 5 nits; give the rest as a count.

Comments must be actionable: "`unwrap` panics when the list is empty; use `first()` and return early" - not verdicts. Cite `file:line`. Finish with: ready / fix first / discuss.

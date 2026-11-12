# Rust glossary

Rust terms met while reviewing Pod Bay MRs, explained for a TypeScript/C# developer. Written by `pb-explain-mr` (it appends new terms from each MR diff) and edited by the team. "First seen" is a `file:line` in the repo at `main` d7d44d9, or an MR link for later terms.

| Term | Meaning | TS/C# analogy | First seen |
| --- | --- | --- | --- |
| `Arc<Mutex<T>>` | `Arc` is a shared, reference-counted pointer; `Mutex` lets one thread at a time change the value inside. Clone the `Arc` to share it. | A shared object guarded by `lock (obj)` in C#. TS has no threads, so no direct match. | `src/ui/updates.rs:30` |
| `Option<T>`, `Result<T, E>` and `?` | `Option` is a value or nothing; `Result` is a value or an error. `?` returns early with the `None` or error if there is one. | `T \| undefined` and `Result` types; `?` is like `a?.b` plus an early `return`, or a `throw` that is typed. | `src/ui/workspace.rs:126` (`Option` and `?`); `src/ops.rs:124` (`Result`) |
| `impl` blocks and traits | `impl Type { ... }` adds methods to a type. A trait is a set of methods a type promises to have, like an interface. `impl Trait for Type` implements it. | Class methods; C# `interface`; TS `interface` plus a class that implements it. | `src/ui/machines.rs:17` (methods on `App`); `src/ui/credits.rs:95` (`impl Default for Pick`) |
| Closure with `move` | An inline function `\|args\| body`. `move` makes it take ownership of the variables it uses, so it can outlive the current function (needed for threads and tasks). | A lambda or arrow function. `move` is like copying captured variables into it so the original scope can end. | `src/proc.rs:112` |
| egui immediate mode | The UI is rebuilt from code every frame. A call like `ui.button(..)` draws the button and returns whether it was clicked right now. No widget tree is kept. | Like calling a render function on every tick, with `if (button("x")) {...}` inline, instead of React state and event handlers. | `src/ui/machines.rs:27` |
| Enums that carry data | Each variant of an `enum` can hold its own fields; `match` must handle every variant. | TS discriminated union; C# records under one base type. | first seen: fix/issue-7-clone-remote-match (origin/main...HEAD) |
| `match` with guards | A `match` arm can add `if condition`; the compiler still checks all cases are covered. | C# `case ... when`, a `switch` with conditions. | first seen: fix/issue-7-clone-remote-match (origin/main...HEAD) |
| Iterator adapters | `filter`, `map`, `find`, `next` chain lazily over a collection. | LINQ `Where`/`Select`/`First`; JS array methods on a lazy sequence. | first seen: fix/issue-7-clone-remote-match (origin/main...HEAD) |

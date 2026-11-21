# tools

General skills, not Pod Bay specific. Install: `claude plugin install tools@podbay-kit`. Skills run as `/tools:<name>`.

| Skill | What it does | Source and license |
|---|---|---|
| `macos-cleaner` | Diagnoses and safely reclaims macOS disk space. | From [daymade/claude-code-skills](https://github.com/daymade/claude-code-skills) (`daymade-macos/macos-cleaner`). MIT, Copyright (c) 2025 daymade; see `skills/macos-cleaner/LICENSE`. Some files have local changes. |
| `unslop` | Cuts AI tells from writing. | Written by Thanh Nguyen, inspired by [theclaymethod/unslop](https://github.com/theclaymethod/unslop). |
| `grill-me` | The interview people start by hand (`/tools:grill-me`) before any task, to settle scope, acceptance criteria and edge cases. It runs `grilling`. | By Matt Pocock: [aihero.dev/skills-grill-me](https://www.aihero.dev/skills-grill-me), code in [mattpocock/skills](https://github.com/mattpocock/skills) (`skills/productivity/grill-me`). MIT, Copyright (c) 2026 Matt Pocock; see `skills/grill-me/LICENSE`. Description changed; calls `tools:grilling`. |
| `grilling` | The engine grill-me runs, and that skills call: rounds of questions, each with a recommended answer. | By Matt Pocock: [aihero.dev/skills-grilling](https://www.aihero.dev/skills-grilling), code in [mattpocock/skills](https://github.com/mattpocock/skills) (`skills/productivity/grilling`). MIT, Copyright (c) 2026 Matt Pocock; see `skills/grilling/LICENSE`. One phrase changed. |

| `wayfinder` | Plans work too big for one session as a map of decision tickets on the issue tracker, resolved one at a time (`/tools:wayfinder`). | By Matt Pocock: [aihero.dev/skills-wayfinder](https://www.aihero.dev/skills-wayfinder), code in [mattpocock/skills](https://github.com/mattpocock/skills) (`skills/engineering/wayfinder`). MIT, Copyright (c) 2026 Matt Pocock; see `skills/wayfinder/LICENSE`. One added note on skills the kit does not have. |

The aihero.dev pages state no license. The MIT terms come from the LICENSE file in each GitHub repo.

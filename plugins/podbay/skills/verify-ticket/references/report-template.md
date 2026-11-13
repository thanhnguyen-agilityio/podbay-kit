# verify-ticket: results.md and mr-comment.md

## results.md (local, full detail)

```markdown
# Results: ticket <T>, MR <M>

| # | Scenario | Result | Observed | Evidence |
| --- | --- | --- | --- | --- |
| S1 | <name> | PASS / FAIL / BLOCKED / NOT RUN | <what the screen showed> | s1.mp4, s1.gif, s1-2.png |

## Notes per scenario
### S1
- Steps done: ...
- Retries: <0-2, why>
- BLOCKED reason: <if any>
```

## mr-comment.md (posted, must stand alone)

Readers on GitLab/GitHub have not seen the plan or this skill. No plan file names, scenario ids from other files, plugin names, local paths or `claude.ai` links. Evidence lines hold placeholders until upload replaces them with the returned markdown.

```markdown
## Verification of #<T> on this MR

**Result:** <n> passed, <n> failed, <n> blocked, out of <n> scenarios.

| Scenario | Covers | Result |
| --- | --- | --- |
| <plain-words name> | <acceptance criterion, short> | ✅ PASS / ❌ FAIL / ⚠️ BLOCKED |

### Environment
- Branch: `<source branch>` at `<short sha>`
- macOS <version>, <arch>
- App: Pod Bay-local <version>, built <yyyy-mm-dd hh:mm tz> from this branch, installed from the dmg

### Bugs found
- <one line per bug: what you did, what happened, what was expected>. Or: None.

### Evidence
<details><summary><scenario name></summary>

<upload: s1.gif>
<upload: s1.mp4>
<upload: s1-2.png>

</details>

### Not covered
- <criterion or risk not tested, and why>. Or leave this section out.
```

Under `--dry-run`, every result is `NOT RUN (dry run)`, Environment says `not built (dry run)` for the app line, and Evidence says `none (dry run)`.

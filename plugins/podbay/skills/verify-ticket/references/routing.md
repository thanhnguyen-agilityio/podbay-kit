# verify-ticket: CLI vs Chrome routing

Decide the route per step, not once per run. A CLI failure on one step moves only that step to Chrome. Always tell the user which route a step used and why.

## Capability check

1. Host: take it from `git remote get-url origin`. An SSH remote may use an alias from `~/.ssh/config` (for example `gitlab.com-work`) that points somewhere else, often a self-hosted GitLab. Resolve the real host with `ssh -G <alias> | awk '/^hostname /{print $2}'`; use that `<host>` everywhere below.
   - `<host>` contains `gitlab` → CLI `glab`, MR.
   - `<host>` is `github.com` → CLI `gh`, PR.
   - Anything else → Chrome for every step.
2. `<repo>` is the path after the host (`group/project`, no `.git`). Pass `-R <host>/<repo>` to every call, so the CLI never falls back to its default host.
3. Run, and record pass/fail for each:
   - GitLab: `glab auth status --hostname <host>`, `glab issue view <T> -R <host>/<repo>`, `glab mr view <M> -R <host>/<repo>`.
   - GitHub: `gh auth status`, `gh issue view <T> -R <repo>`, `gh pr view <M> -R <repo>`.
4. GitLab project id, needed for API calls: `glab api projects/<url-encoded repo> --jq .id`.

Report in one line, for example: `gitlab.com · glab 1.128 authed · issue 3 ok · MR 2 ok → reads: CLI`.

## Chrome (fallback)

Claude in Chrome only: the user's real, signed-in Chrome. Load its tools in one ToolSearch call (core set plus `get_page_text`, `find`, `file_upload`). Open each page in a new tab. Page URLs:

| | GitLab | GitHub |
| --- | --- | --- |
| Ticket | `https://<host>/<repo>/-/issues/<T>` | `https://github.com/<repo>/issues/<T>` |
| MR/PR | `https://<host>/<repo>/-/merge_requests/<M>` | `https://github.com/<repo>/pull/<M>` |
| Diff | MR page, Changes tab | PR page, Files changed tab |

`<host>` is the resolved real host from the capability check, never the SSH alias. If the page shows a sign-in, stop and ask the user to sign in.

## Reads

| Step | GitLab CLI | GitHub CLI | Chrome |
| --- | --- | --- | --- |
| Ticket + comments | `glab issue view <T> -R <host>/<repo> --comments` | `gh issue view <T> -R <repo> --comments` | ticket page, `get_page_text` |
| MR/PR body + branch | `glab mr view <M> -R <host>/<repo> -F json` (`source_branch`, `sha`) | `gh pr view <M> -R <repo> --json title,body,headRefName,headRefOid` | MR/PR page |
| Diff | `glab mr diff <M> -R <host>/<repo>` | `gh pr diff <M> -R <repo>` | Changes / Files tab |

## Posting

Only after the first approval (step 6a). Text body comes from a file; the podbay guard scans files passed with `-F key=@file` and `--body-file`-style arguments, so never put the body inline.

### GitLab

1. Media: for each file, once: `glab api -X POST projects/<id>/uploads -F file=@<out>/<file>`. Take the `markdown` field from the answer.
   - glab 1.128 is known to return HTTP 400 here. On any failure, do not retry and do not switch to curl or tokens: use Chrome for media (below).
2. Put the returned markdown links into a copy of the approved draft: `<scratchpad>/mr-comment-final.md`. Rerun both scans on it.
3. Show the final file and this command, wait for yes, then run it:
   `glab api -X POST projects/<id>/merge_requests/<M>/notes -F body=@<scratchpad>/mr-comment-final.md`
   (Same as `glab mr note`, but the body comes from a scanned file instead of `-m`.)
4. Chrome media route: open the MR page, click the comment box, attach each file with `file_upload` so GitLab inserts the links, paste the approved text around them, switch to Preview, screenshot it, show it, wait for yes, then click Comment.

### GitHub

- Text only: show the file and `gh pr comment <M> -R <repo> --body-file <scratchpad>/mr-comment-final.md`, wait for yes, run it.
- With media (the normal case): `gh` cannot attach files. Use Chrome: PR page → comment box → `file_upload` each file (GitHub inserts the links) → paste the approved text around them → Preview tab → screenshot, show, wait for yes → click Comment.

### After posting

- GitLab: `glab api projects/<id>/merge_requests/<M>/notes --jq '.[0].body'` (newest first), or reload in Chrome.
- GitHub: `gh pr view <M> -R <repo> --comments`, or reload in Chrome.
- Check every image and video link is present and, in Chrome, that it renders.

The Chrome route is not covered by the podbay guard, so the step 6a scans are the only secret check for it.

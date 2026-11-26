#!/bin/bash
# Tests pb-merge-check.sh and pb-tier.sh with a fake glab and a throwaway git repo.
# Usage: test-merge-check.sh   (prints ok/FAIL per case and a passed/failed line; exit 1 on any failure)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MC="$HERE/pb-merge-check.sh"; TIER="$HERE/pb-tier.sh"
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; }

# Repo: origin/feat/epic, then a change on top (head). A second change touches a sensitive path.
R="$D/repo"; git init -q -b main "$R"; cd "$R" || exit 1
git -c user.name=t -c user.email=t@x commit -q --allow-empty -m base
git branch feat/epic; git update-ref refs/remotes/origin/feat/epic feat/epic; git update-ref refs/remotes/origin/develop feat/epic
git switch -q -c fix/one; mkdir -p src/ui docs; echo a > src/ui/table.rs; git add .; git -c user.name=t -c user.email=t@x commit -q -m change
HEAD_SHA="$(git rev-parse HEAD)"
git switch -q -c fix/two; mkdir -p src/net; echo b > src/net/peer.rs; git add .; git -c user.name=t -c user.email=t@x commit -q -m net
NET_SHA="$(git rev-parse HEAD)"
git switch -q -c fix/docs feat/epic; mkdir -p docs; echo e > docs/guide.md; git add docs/guide.md; git -c user.name=t -c user.email=t@x commit -q -m docs
DOCS_SHA="$(git rev-parse HEAD)"
git switch -q fix/one
mkdir -p .podbay/review .podbay/ci; printf '.podbay/\n' >> .git/info/exclude

# Fake glab: MR 1 = head of fix/one into feat/epic; 2 = into main; 3 = sensitive (fix/two); 4 = sensitive with label; 5 = merged.
mkdir -p "$D/bin"
cat > "$D/bin/glab" <<FAKE
#!/bin/bash
if [ "\$1 \$2" = "mr view" ]; then
  case "\$3" in
    1) echo '{"state":"opened","sha":"$HEAD_SHA","target_branch":"feat/epic","labels":[]}' ;;
    2) echo '{"state":"opened","sha":"$HEAD_SHA","target_branch":"main","labels":[]}' ;;
    3) echo '{"state":"opened","sha":"$NET_SHA","target_branch":"feat/epic","labels":[]}' ;;
    4) echo '{"state":"opened","sha":"$NET_SHA","target_branch":"feat/epic","labels":["human-reviewed"]}' ;;
    5) echo '{"state":"merged","sha":"$HEAD_SHA","target_branch":"feat/epic","labels":[]}' ;;
    6) echo '{"state":"opened","sha":"$NET_SHA","target_branch":"feat/epic","labels":["area:network","human-reviewed"]}' ;;
    7) echo '{"state":"opened","sha":"$HEAD_SHA","target_branch":"feat/epic","labels":[]}' ;;
    8) echo '{"state":"opened","sha":"feat/x","target_branch":"feat/epic","labels":[]}' ;;
    10) echo '{"state":"opened","sha":"$DOCS_SHA","target_branch":"feat/epic","labels":[]}' ;;
    13) echo '{"state":"opened","sha":"$NET_SHA","target_branch":"feat/epic","labels":["needs-human"]}' ;;
    14) echo '{"state":"opened","sha":"$NET_SHA","target_branch":"feat/epic","labels":["pb::human-reviewed"]}' ;;
    11) echo '{"state":"opened","sha":"$HEAD_SHA","target_branch":"develop","labels":[]}' ;;
    12) echo '{"state":"opened","sha":"$HEAD_SHA","target_branch":"release/2026.11.20","labels":[]}' ;;
    *) exit 1 ;;
  esac
  exit 0
fi
[ "\$1" = api ] && { case "\$2" in projects/*/merge_requests/7/notes*) echo '[{"body":"Isolated review, round 1, commit ${HEAD_SHA:0:7}\\n\\nNo findings."}]' ;; projects/*/notes*) echo '[]' ;; *) echo '{"id":1}' ;; esac; exit 0; }
exit 1
FAKE
chmod +x "$D/bin/glab"; export PATH="$D/bin:$PATH"

review() { printf 'Findings: none.\nReviewer: fresh agent, claude-opus-5-5, 2026-11-21, head %s\n' "${1:0:7}" > .podbay/review/fix-one-2026-11-21-r1.md; }
ci() { printf 'PBCI-HEAD sha=%s checkout=x target=y\npb-ci %s build=pass clippy=pass test=%s mesh=pass total=1s\n' "$1" "${1:0:12}" "${2:-pass}" > ".podbay/ci/${1:0:12}.log"; }
# mc <want-rc> <label> <iid> [grep pattern in output]
mc() { local out rc; out="$("$MC" "$3" -R group/project --checkout "$R" 2>&1)"; rc=$?
  if [ "$rc" = "$1" ] && { [ -z "${4:-}" ] || printf '%s' "$out" | grep -q -- "$4"; }; then ok "$2"; else bad "$2 (rc $rc: $(printf '%s' "$out" | grep -m1 -E 'FAIL|merge-check|usage' | cut -c1-110))"; fi; }

mc 1 "no review and no pb-ci: blocked" 1 "no isolated review"
review "$HEAD_SHA"
mc 1 "review but no pb-ci log: blocked" 1 "no pb-ci log"
ci "$HEAD_SHA" fail
mc 1 "pb-ci failed on head: blocked" 1 "pb-ci failed"
ci "$HEAD_SHA" pass
mc 0 "review, pb-ci and head match: pass, pinned to the head" 1 "--sha $HEAD_SHA"
review "$NET_SHA"
mc 1 "review of another commit: blocked" 1 "no isolated review of head"
review "$HEAD_SHA"
printf 'PBCI-HEAD sha=%s\npb-ci %s build=pass total=1s\n' "$NET_SHA" "${HEAD_SHA:0:12}" > ".podbay/ci/${HEAD_SHA:0:12}.log"
mc 1 "pb-ci log built from another commit: blocked" 1 "another commit"
ci "$HEAD_SHA" pass
mc 1 "target main: a person merges" 2 "a person merges"
mc 0 "target develop: team-shared, the orchestrator may merge" 11 "not person-only (pb-targets.sh)"
mc 1 "target old release branch: a person merges" 12 "a person merges"
mc 1 "MR not open: blocked" 5 "not open"
review "$NET_SHA"; ci "$NET_SHA" pass
mc 1 "sensitive change without human-reviewed: blocked" 3 "label human-reviewed"
mc 0 "sensitive change with human-reviewed: pass" 4 "merge-check: OK"
mc 0 "sensitive change with another label next to human-reviewed: pass" 6 "merge-check: OK"
mc 1 "needs-human is never approval: blocked" 13 "label human-reviewed"
mc 1 "the old pb::human-reviewed no longer counts: blocked" 14 "label human-reviewed"
mc 2 "MR head that is not a full sha: refused" 8 "no head sha"
review "$HEAD_SHA"
printf 'PBCI-HEAD sha=%s\npb-ci %s total=1s\n' "$HEAD_SHA" "${HEAD_SHA:0:12}" > ".podbay/ci/${HEAD_SHA:0:12}.log"
mc 1 "pb-ci log with no build and test steps: blocked" 1 "build=pass"
printf 'PBCI-HEAD sha=%s\nPBCI build=pass\n' "$HEAD_SHA" > ".podbay/ci/${HEAD_SHA:0:12}.log"
mc 1 "pb-ci log with no summary (run not finished): blocked" 1 "no summary"
ci "$HEAD_SHA" pass
rm -f .podbay/review/*.md; printf 'Notes: we are ahead, head %s\n' "${HEAD_SHA:0:7}" > .podbay/review/other.md
mc 1 "a line that is not the Reviewer line does not count as a review" 1 "no isolated review of head"
rm -f .podbay/review/*.md
mc 0 "review found in an MR note: pass" 7 "MR note"
review "$HEAD_SHA"
printf '**Reviewer:** "fresh agent, claude-opus-5-5, 2026-11-22, head %s".\n' "${HEAD_SHA:0:7}" > .podbay/review/fix-one-2026-11-22-r2.md; rm -f .podbay/review/fix-one-2026-11-21-r1.md
mc 0 "bold Reviewer line from the reviewer prompt counts" 1 "merge-check: OK"
printf 'PBCI-HEAD sha=%s\npb-ci %s build=pass test=pass total=1s\n' "$HEAD_SHA" "${HEAD_SHA:0:12}" > ".podbay/ci/${HEAD_SHA:0:12}.log"
mc 1 "pb-ci summary without clippy=pass: blocked" 1 "clippy=pass"
ci "$HEAD_SHA" pass
printf 'Reviewer: fresh agent, claude-opus-5-5, 2026-11-22, head %s\n' "${DOCS_SHA:0:7}" > .podbay/review/fix-docs-r1.md
mc 0 "light (docs-only) change with a review and no pb-ci log: pass" 10 "pb-ci optional"
printf 'PBCI-HEAD sha=%s\npb-ci %s build=fail total=1s\n' "$DOCS_SHA" "${DOCS_SHA:0:12}" > ".podbay/ci/${DOCS_SHA:0:12}.log"
mc 1 "light change whose pb-ci log failed: blocked" 10 "pb-ci failed"
mc 2 "unknown MR: usage error" 9
out="$("$MC" 1 --checkout "$R" 2>&1)"; [ $? -eq 2 ] && ok "missing -R: usage error" || bad "missing -R: usage error"

[ "$("$TIER" --files docs/a.md site/i.html CHANGELOG.md)" = "tier=light" ] && ok "tier: docs and site only is light" || bad "tier: docs and site only is light"
[ "$("$TIER" --files src/ui/table.rs docs/a.md)" = "tier=full" ] && ok "tier: code is full" || bad "tier: code is full"
[ "$("$TIER" --files src/ui/kit/button.rs | grep -c '^sensitive:')" = 1 ] && ok "tier: UI kit is sensitive" || bad "tier: UI kit is sensitive"
[ "$("$TIER" --files Cargo.lock src/secure.rs src/state.rs | grep -c '^sensitive:')" = 3 ] && ok "tier: dependencies, auth, state are sensitive" || bad "tier: dependencies, auth, state are sensitive"
[ "$("$TIER" feat/epic "$HEAD_SHA" "$R" | head -1)" = "tier=full" ] && ok "tier from git diff" || bad "tier from git diff"

[ "$("$TIER" --files crates/x/Cargo.toml crates/x/build.rs | grep -c '^sensitive:')" = 2 ] && ok "tier: nested Cargo.toml and build.rs are sensitive" || bad "tier: nested Cargo.toml and build.rs are sensitive"
[ "$("$TIER" --files db/Migrations/001.sql src/AuthToken.rs | grep -c '^sensitive:')" = 2 ] && ok "tier: sensitive names match in any case" || bad "tier: sensitive names match in any case"
# Renamed and non-ASCII sensitive paths.
git switch -q -c fix/move feat/epic; mkdir -p src/net; echo c > src/net/p.rs; git add src/net/p.rs; git -c user.name=t -c user.email=t@x commit -q -m add
git branch -f base-move; mkdir -p docs; git mv src/net/p.rs docs/p.md; git -c user.name=t -c user.email=t@x commit -q -m move
out="$("$TIER" base-move fix/move "$R")"
printf '%s' "$out" | grep -q '^sensitive: src/net/p.rs' && ok "tier: a sensitive file moved away is still sensitive" || bad "tier: a sensitive file moved away is still sensitive (got: $(printf '%s' "$out" | tr '\n' ' '))"
echo d > "src/net/p\303\251er.rs" 2>/dev/null; printf 'x' > "src/net/péer.rs"; git add src/net; git -c user.name=t -c user.email=t@x commit -q -m accent
out="$("$TIER" fix/move~1 fix/move "$R")"
printf '%s' "$out" | grep -q '^sensitive: src/net/p' && ok "tier: a non-ASCII sensitive path is still sensitive" || bad "tier: a non-ASCII sensitive path is still sensitive (got: $(printf '%s' "$out" | tr '\n' ' '))"
git switch -q fix/one

echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]

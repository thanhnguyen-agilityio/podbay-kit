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
git branch feat/epic; git update-ref refs/remotes/origin/feat/epic feat/epic
git switch -q -c fix/one; mkdir -p src/ui docs; echo a > src/ui/table.rs; git add .; git -c user.name=t -c user.email=t@x commit -q -m change
HEAD_SHA="$(git rev-parse HEAD)"
git switch -q -c fix/two; mkdir -p src/net; echo b > src/net/peer.rs; git add .; git -c user.name=t -c user.email=t@x commit -q -m net
NET_SHA="$(git rev-parse HEAD)"
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
    4) echo '{"state":"opened","sha":"$NET_SHA","target_branch":"feat/epic","labels":["pb::human-reviewed"]}' ;;
    5) echo '{"state":"merged","sha":"$HEAD_SHA","target_branch":"feat/epic","labels":[]}' ;;
    *) exit 1 ;;
  esac
  exit 0
fi
[ "\$1" = api ] && { case "\$2" in projects/*/notes*) echo '[]' ;; *) echo '{"id":1}' ;; esac; exit 0; }
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
mc 1 "MR not open: blocked" 5 "not open"
review "$NET_SHA"; ci "$NET_SHA" pass
mc 1 "sensitive change without pb::human-reviewed: blocked" 3 "pb::human-reviewed"
mc 0 "sensitive change with pb::human-reviewed: pass" 4 "merge-check: OK"
mc 2 "unknown MR: usage error" 9
out="$("$MC" 1 --checkout "$R" 2>&1)"; [ $? -eq 2 ] && ok "missing -R: usage error" || bad "missing -R: usage error"

[ "$("$TIER" --files docs/a.md site/i.html CHANGELOG.md)" = "tier=light" ] && ok "tier: docs and site only is light" || bad "tier: docs and site only is light"
[ "$("$TIER" --files src/ui/table.rs docs/a.md)" = "tier=full" ] && ok "tier: code is full" || bad "tier: code is full"
[ "$("$TIER" --files src/ui/kit/button.rs | grep -c '^sensitive:')" = 1 ] && ok "tier: UI kit is sensitive" || bad "tier: UI kit is sensitive"
[ "$("$TIER" --files Cargo.lock src/secure.rs src/state.rs | grep -c '^sensitive:')" = 3 ] && ok "tier: dependencies, auth, state are sensitive" || bad "tier: dependencies, auth, state are sensitive"
[ "$("$TIER" feat/epic "$HEAD_SHA" "$R" | head -1)" = "tier=full" ] && ok "tier from git diff" || bad "tier from git diff"

echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]

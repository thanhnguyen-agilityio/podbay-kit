#!/bin/bash
# pb-guard.sh: Claude Code PreToolUse hook (Bash tool only) that makes the podbay plugin's "never" rules deterministic.
# Source of the rules: reference/contract.md (Merge requests, Writing and publishing, Gates), reference/preflight.md (Notes).
# Sibling scripts (publish-check.sh, private-ref-check.sh) are resolved from this script's own directory.
# Exit 0 = allow. Exit 2 = block, with the reason and the allowed route on stderr.
# Blocks:
#   1. cargo fmt / rustfmt anywhere in the command (the code is not rustfmt-formatted).
#   2. git push with --force, -f, --force-with-lease, +refspec, --all or --mirror.
#   3. git push to a branch in PB_NO_PUSH (pb-targets.sh: main, master, develop, release/*). A push to main or master is allowed only when env PB_KIT_REPO is set to a repo path and the push targets that repo (git -C <path> inside it, or cd into it first). Unset: never allowed.
#   4. glab mr merge, glab mr approve, glab api calls to /merge or /approve endpoints. Merge is allowed only into a target that is not in PB_PERSON_MERGES (pb-targets.sh: main, master, release/*), read from glab mr view; unsure -> block (Gate 2).
#   5. Publishing to GitLab without a secret scan (also the file in -m "$(cat <file>)"): glab issue|mr create|note|update and glab api with a non-GET method or
#      field flags. Runs scripts/publish-check.sh on each --description-file / -F key=@file / --input file, and on the whole
#      command text (inline -m / --description). Match, missing file, unresolvable path or scanner error -> block.
#   6. Private references in that same text (finding ids, triage file names, review artifact, gate or grilling words, internal
#      labels): scripts/private-ref-check.sh on the same files and on the command text with file-path arguments removed.
#   7. cargo build|test|clippy|run|check (and pb-ci.sh) in command position when free disk is under PB_DISK_FLOOR_GB
#      (whole GB, default 10). Tests fake free space with PB_FREE_GB_OVERRIDE, read only when PB_GUARD_TEST=1.
#   8. New labels: glab label create|edit|delete, glab api writes to /labels, and a label added by glab issue|mr
#      create|update (--label, -l) or a glab api write (labels=, add_labels=) that the repo does not have
#      (glab label list; unreadable -> block). GitLab creates a missing label silently when one is added.
#   9. Uploads (any glab api or curl call to /uploads or /wikis/attachments, glab ... --attach, glab release
#      upload|create, a curl form to an API URL built from a variable, and the Chrome or browser upload tools): answered
#      with "ask", so the person's permission prompt decides; checked after every block. In a mode with no prompt for
#      the person (bypassPermissions, dontAsk, unknown) they are blocked. Accepted false asks: a GET of an upload
#      endpoint, `glab release create` without files, a curl POST to an API URL built from a variable.
# Compound commands are split on && || ; | & and newlines; each piece is checked. Parsing is loose and errs toward blocking.
# A bare `git push` (or `git push <remote> HEAD`) is checked against the target checkout's current branch.
# Not enforced: wrappers (bash script.sh, eval), python calls to the API, and curl to the API other than uploads.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# The "may push to main" exception exists only when PB_KIT_REPO names an existing directory.
KIT_REPO=""
if [ -n "${PB_KIT_REPO:-}" ] && [ -d "$PB_KIT_REPO" ]; then KIT_REPO="$(cd "$PB_KIT_REPO" && pwd -P)"; fi
PC="$HERE/publish-check.sh"
# Protected branch lists. If the file is missing, every push and merge is blocked (errs toward blocking).
# shellcheck source=pb-targets.sh
. "$HERE/pb-targets.sh" 2>/dev/null || { PB_PERSON_MERGES="*"; PB_NO_PUSH="*"; pb_in_list() { return 0; }; }
PR="$HERE/private-ref-check.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/pb-guard.XXXXXX")" || exit 0
trap 'rm -rf "$TMP"' EXIT
CMDF="$TMP/command.txt"

meta="$(python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
ti = d.get("tool_input") or {}
open(sys.argv[1], "w").write(ti.get("command") or "")
print(d.get("tool_name") or "")
print(d.get("cwd") or "")
print(d.get("permission_mode") or "")
' "$CMDF" 2>/dev/null)" || exit 0
TOOL="$(printf '%s\n' "$meta" | sed -n 1p)"
CWD="$(printf '%s\n' "$meta" | sed -n 2p)"
PMODE="$(printf '%s\n' "$meta" | sed -n 3p)"

# ask_upload: an upload goes to the person's permission prompt. Only modes where the docs promise that prompt get
# "ask" (auto too: there a hook's "ask" goes to the prompt and the classifier does not decide it; an empty mode is a
# client that sends no mode, which prompts as default); any other mode (bypassPermissions, dontAsk, unknown) blocks.
ask_upload() {
  case "$PMODE" in
    ""|default|acceptEdits|plan|auto) ;;
    *) block "This uploads a file, and in permission mode '$PMODE' no prompt reaches the person, so nobody can say yes. Uploads of screenshots or files need the person's yes in the session's own window, even for invented data. Leave the file out and report it, or run in a mode with prompts." ;;
  esac
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"pb-guard: this uploads a file. Uploads need the person'"'"'s yes in this window, even for invented data. Approve only if you want this file uploaded."}}'
  exit 0
}
[ -n "$CWD" ] || CWD="$PWD"

PRIV_HINT="GitLab readers can't see the triage notes: rewrite in plain terms (no finding ids, triage file names, review artifact, gate or grilling words, internal labels)."

block() {
  printf 'pb-guard: BLOCKED. %s\n' "$1" >&2
  exit 2
}

# Only Bash and the Chrome upload tool reach here (hooks.json matcher).
case "$TOOL" in mcp__*[Cc]hrome*__file_upload|mcp__*[Cc]hrome*__upload_image|mcp__*[Bb]rowser*__file_upload|mcp__*[Bb]rowser*__upload_image) ask_upload ;; esac
[ "$TOOL" = "Bash" ] || exit 0
CMD="$(cat "$CMDF")"
[ -n "$CMD" ] || exit 0

# resolve <path> <base>: print the absolute physical path, or fail if it has variables or does not exist.
resolve() {
  local p="$1" base="$2"
  p="${p%\"}"; p="${p#\"}"; p="${p%\'}"; p="${p#\'}"
  case "$p" in "~") p="$HOME" ;; "~/"*) p="$HOME/${p#\~/}" ;; esac
  p="${p//\$HOME/$HOME}"; p="${p//\$\{HOME\}/$HOME}"
  case "$p" in *'$'*|*'`'*) return 1 ;; esac
  case "$p" in /*) ;; *) p="$base/$p" ;; esac
  if [ -d "$p" ]; then (cd "$p" && pwd -P)
  elif [ -e "$p" ]; then
    local d; d="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)" || return 1
    printf '%s/%s\n' "$d" "$(basename "$p")"
  else return 1; fi
}

# gb_num <text>: a whole number of GB, read in base 10 ("08" is 8), 1 to 6 digits; anything else prints nothing.
gb_num() { case "$1" in ''|*[!0-9]*) return 0 ;; esac; [ "${#1}" -le 6 ] || return 0; echo $(( 10#$1 )); }
# Command position: after plain or quoted VAR=value prefixes, env, time, nice [-n N], command, exec.
CMDPOS='^(([A-Za-z_][A-Za-z0-9_]*=("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]*)|env|time|nice([[:space:]]+-n[[:space:]]*-?[0-9]+)?|command|exec)[[:space:]]+)*'
CARGO_RE="${CMDPOS}([^[:space:]]*/)?cargo([[:space:]]+[-+][^[:space:]]*)*[[:space:]]+(build|test|clippy|run|check|nextest|b|t|r|c)([[:space:]]|\$)"
PBCI_RE="${CMDPOS}((bash|sh|zsh)[[:space:]]+)?[^[:space:]]*pb-ci\.sh([[:space:]]|\$)"

in_kit() { [ -n "$KIT_REPO" ] || return 1; case "$1" in "$KIT_REPO"|"$KIT_REPO"/*) return 0 ;; esac; return 1; }

# 1. rustfmt
if printf '%s' "$CMD" | grep -Eq '(^|[^[:alnum:]_-])(cargo[[:space:]]+(\+[^[:space:]]+[[:space:]]+)?fmt|rustfmt)([^[:alnum:]_-]|$)'; then
  block "cargo fmt / rustfmt is never run here: the code is not rustfmt-formatted and reformatting creates churn. Match the surrounding style by hand; check with clippy and cargo test --locked."
fi

SEGS="$(printf '%s' "$CMD" | sed -E 's/(&&|\|\||;|\||&)/\
/g')"

PUBLISH=0
FILES=""
CUR="$CWD"

while IFS= read -r seg; do
  seg="${seg#"${seg%%[![:space:]]*}"}"; seg="${seg#\(}"
  [ -n "$seg" ] || continue

  # 7. disk floor for cargo builds and pb-ci
  if [[ "$seg" =~ $CARGO_RE ]] || [[ "$seg" =~ $PBCI_RE ]]; then
    floor="$(gb_num "${PB_DISK_FLOOR_GB:-}")"; [ -n "$floor" ] || floor=10
    where="${CARGO_TARGET_DIR:-$CUR}"
    if [[ "$seg" =~ CARGO_TARGET_DIR=(\"[^\"]+\"|\'[^\']+\'|[^[:space:]]+) ]]; then
      w="${BASH_REMATCH[1]}"; w="${w//\"/}"; w="${w//\'/}"
      case "$w" in "~"|"~/"*) w="$HOME${w#\~}" ;; esac
      w="${w//\$\{HOME\}/$HOME}"; w="${w//\$HOME/$HOME}"
      case "$w" in *'$'*|*'`'*) ;; *) where="$w" ;; esac
    fi
    case "$where" in /*) ;; *) where="$CUR/$where" ;; esac
    while [ ! -e "$where" ] && [ "$where" != / ]; do where="$(dirname "$where")"; done
    ov=""; [ "${PB_GUARD_TEST:-}" = 1 ] && ov="$(gb_num "${PB_FREE_GB_OVERRIDE:-}")"
    if [ -n "$ov" ]; then free_kb=$(( ov * 1048576 ))
    else free_kb="$(df -Pk "$where" 2>/dev/null | awk 'NR == 2 { print $4 }')"; fi
    case "$free_kb" in ''|*[!0-9]*) free_kb="" ;; esac
    [ "${#free_kb}" -le 15 ] || free_kb=""
    if [ -n "$free_kb" ] && [ "$free_kb" -lt $(( floor * 1048576 )) ]; then
      free_gb="$(awk -v k="$free_kb" 'BEGIN { printf "%.1f", k / 1048576 }')"
      block "Only $free_gb GB free on the disk that holds $where; cargo builds and pb-ci need at least $floor GB (env PB_DISK_FLOOR_GB). A full disk fails the build halfway. Free space first, then rerun: old worktrees (git worktree list, then git worktree remove <path>), stale target folders (du -sh ~/.cache/cargo-target/* */target, then remove the ones no checkout uses), and idle Docker data (docker system df; docker volume rm pb-ci-target when no pb-ci runs). Ask the user before deleting anything that is not yours."
    fi
  fi

  # track cd for the PB_KIT_REPO exception
  if [[ "$seg" =~ ^cd[[:space:]]+(\"[^\"]+\"|\'[^\']+\'|[^[:space:]]+) ]]; then
    n="$(resolve "${BASH_REMATCH[1]}" "$CUR")" && CUR="$n"
    continue
  fi

  # 2 and 3. git push
  if [[ "$seg" =~ (^|[[:space:]])git[[:space:]]+(.*[[:space:]])?push([[:space:]]|\)|$) ]]; then
    rest="${seg#* push}"; rest="${rest//\"/}"; rest="${rest//\'/}"; rest="${rest//)/}"
    if printf '%s' "$rest" | grep -Eq '(^|[[:space:]])(--force[a-z-]*|--all|--mirror|-[a-zA-Z]*f[a-zA-Z]*|\+[^[:space:]]+)([[:space:]=]|$)'; then
      block "git push with --force, -f, --force-with-lease, +refspec, --all or --mirror is never allowed. Push the branch normally (git push -u origin <branch>) and let a person handle history."
    fi
    target="$CUR"; cbad=0
    if [[ "$seg" =~ (^|[[:space:]])-C[[:space:]]*(\"[^\"]+\"|\'[^\']+\'|[^[:space:]]+) ]]; then
      target="$(resolve "${BASH_REMATCH[2]}" "$CUR")" || { target=""; cbad=1; }
    fi
    # Words after "push", without options; the value of -o/--push-option/--repo/--receive-pack/--exec is
    # skipped too. Globbing stays off so a * in a refspec is not expanded.
    set -f
    args=""; skip=0
    for w in $rest; do
      if [ "$skip" = 1 ]; then skip=0; continue; fi
      case "$w" in
        -o|--push-option|--repo|--receive-pack|--exec) skip=1 ;;
        -*) ;;
        *) args="$args $w" ;;
      esac
    done
    # Destination of each refspec after the remote (the part after ":", without refs/heads/). A wildcard
    # or an empty destination (":", the matching refspec) can reach any branch: block it. A bare push,
    # or a HEAD or @ refspec, pushes the current branch.
    dests=""; n=0; cur=0
    for w in $args; do
      n=$((n + 1))
      [ "$n" = 1 ] && continue
      case "$w" in HEAD|@) cur=1 ;; esac
      d="${w##*:}"; d="${d#refs/heads/}"; d="${d#heads/}"
      case "$d" in
        *'*'*|"") block "git push with a wildcard or matching refspec ($w) can push main or develop and is never allowed. Push one named branch (git push -u origin <branch>)." ;;
      esac
      dests="$dests $d"
    done
    if [ "$n" -lt 2 ] || [ "$cur" = 1 ]; then
      [ "$cbad" = 1 ] && block "git push of the current branch with a -C path the guard cannot resolve (a variable or a missing folder) is blocked: it cannot tell whether that checkout is on main or develop. Name the branch (git -C <path> push origin <branch>) or use a literal path."
      dests="$dests $(git -C "${target:-$CUR}" symbolic-ref --short -q HEAD 2>/dev/null)"
    fi
    for d in $dests; do
      case "$d" in HEAD|@) continue ;; esac
      pb_in_list "$d" "$PB_NO_PUSH" || continue
      case "$d" in
        main|master)
          if [ -n "$target" ] && in_kit "$target"; then continue; fi
          block "git push to $d is never allowed (Gate 2: a person merges). Push a branch (git push -u origin fix/issue-<n>-<slug>) and open an MR. Main is pushable only in the repo named by env PB_KIT_REPO, if set." ;;
        *) block "git push to $d is never allowed: it changes only by MR (contract, Gate 2). Push your own branch (git push -u origin fix/issue-<n>-<slug>) and open a Draft MR into $d." ;;
      esac
    done
    set +f
  fi

  # 4. glab merge / approve
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?mr[[:space:]]+approve([[:space:]]|$)'; then
    block "glab mr approve is never allowed (Gate 2: a person approves every MR). Leave the MR open and report its URL."
  fi
  # Merge is allowed only into a branch that is not in PB_PERSON_MERGES (for example develop or an
  # epic's feat/<name>). The target comes from `glab mr view <n> --output json`; unsure -> block.
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?mr[[:space:]]+merge([[:space:]]|$)'; then
    margs="${seg#*mr merge}"; margs="${margs//\"/}"; margs="${margs//\'/}"
    mrid="$(set -f; printf '%s\n' $margs | grep -E '^!?[0-9]+$' | head -1)"; mrid="${mrid#!}"
    mrepo=""
    if [[ "$seg" =~ (^|[[:space:]])(-R|--repo)[[:space:]=]+([^[:space:]]+) ]]; then mrepo="${BASH_REMATCH[3]}"; fi
    [ -n "$mrid" ] || block "glab mr merge needs an explicit MR number, so the guard can check its target branch (Gate 2: a person merges into main)."
    mtarget="$(cd "$CUR" 2>/dev/null && glab mr view "$mrid" ${mrepo:+-R "$mrepo"} --output json 2>/dev/null |
      python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("target_branch") or "")
except Exception: print("")' 2>/dev/null)"
    case "$mtarget" in
      "") block "glab mr merge: could not read the target branch of MR !$mrid, so it is blocked (Gate 2: a person merges into main)." ;;
    esac
    if pb_in_list "$mtarget" "$PB_PERSON_MERGES"; then
      block "glab mr merge into $mtarget is never allowed (Gate 2: a person merges into $PB_PERSON_MERGES). Leave the MR open and report its URL."
    fi
  fi
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?api[[:space:]]' &&
     printf '%s' "$seg" | grep -Eq '/(merge|approve|unapprove)([^[:alnum:]_-]|$)'; then
    block "glab api calls to /merge or /approve endpoints are never allowed (Gate 2: a person merges and approves every MR)."
  fi

  # 8. labels: a skill never creates a label (contract, Labels); only existing labels may be added.
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?label[[:space:]]+(create|edit|delete|update)([[:space:]]|$)'; then
    block "glab label create, edit or delete is never run by a skill: only a person creates or changes labels (contract, Labels). Use an existing label (glab label list -R <repo>), or stop and report that the label is missing."
  fi
  lmode=""
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?(issue|mr)[[:space:]]+(create|update)([[:space:]]|$)'; then lmode=flag; fi
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?api[[:space:]]' &&
     printf '%s' "$seg" | grep -Eiq '(-X|--method)[[:space:]=]*(POST|PUT|PATCH|DELETE)|-XPOST|-XPUT|-XPATCH|-XDELETE|(^|[[:space:]])(-F|-f|--field|--raw-field|--input)([[:space:]=]|[^[:space:]-])'; then
    if printf '%s' "$seg" | grep -Eq '/labels([/?[:space:]]|$)'; then
      block "glab api writes to /labels are never run by a skill: only a person creates or changes labels (contract, Labels)."
    fi
    lmode=field
  fi
  if [ -n "$lmode" ]; then
    labs="$(SEG="$seg" LMODE="$lmode" python3 -c '
import os, re, shlex
s = os.environ["SEG"]; mode = os.environ["LMODE"]
try:
    w = shlex.split(s)
except ValueError:
    w = s.split()
out = []
i = 0
while i < len(w):
    t = w[i]
    if mode == "flag" and t in ("--label", "-l") and i + 1 < len(w):
        out += w[i + 1].split(","); i += 2; continue
    if mode == "flag" and t.startswith("--label="):
        out += t[len("--label="):].split(",")
    elif mode == "flag" and t.startswith("-l") and not t.startswith("--") and len(t) > 2:
        out += t[2:].lstrip("=").split(",")
    if mode == "field":
        f = re.sub(r"^(--field=|--raw-field=|-f|-F)", "", t)
        m = re.match(r"^(add_)?labels(\[\])?=(.*)$", f)
        if m:
            out += m.group(3).split(",")
        for q in re.findall(r"[?&](?:add_)?labels(?:\[\]|%5B%5D)?=([^&]*)", t):
            out += q.split(",")
    i += 1
for x in out:
    x = x.strip()
    if x:
        print(x)
' 2>/dev/null)"
    if [ -n "$labs" ]; then
      lrepo=""
      if [[ "$seg" =~ (^|[[:space:]])(-R|--repo)[[:space:]=]+([^[:space:]]+) ]]; then lrepo="${BASH_REMATCH[3]}"; lrepo="${lrepo//\"/}"; lrepo="${lrepo//\'/}"; fi
      have="$(cd "$CUR" 2>/dev/null && glab label list ${lrepo:+-R "$lrepo"} --per-page 100 --output json 2>/dev/null |
        python3 -c 'import json,sys
try:
    for x in json.load(sys.stdin): print(x.get("name") or "")
except Exception: pass' 2>/dev/null)"
      [ -n "$have" ] || block "Could not read the repo's labels (glab label list), so adding labels is blocked: GitLab would create a missing label silently. Check glab auth and the -R repo, then retry."
      while IFS= read -r lab; do
        [ "$lab" = human-reviewed ] && block "Only the person who reviewed adds the merge-gate label human-reviewed; a skill or session never adds it (contract, Gate 2). Leave the MR open and report that it needs a person's review."
        printf '%s\n' "$have" | grep -Fxq -- "$lab" ||
          block "Label '$lab' does not exist on the repo, and a skill never creates a label (contract, Labels). Use an existing one (glab label list -R <repo>), or stop and report that '$lab' is missing so a person can decide."
      done <<< "$labs"
    fi
  fi

  # 5. publishing
  is_pub=0
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?(issue|mr)[[:space:]]+(create|note|update)([[:space:]]|$)'; then is_pub=1; fi
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?api[[:space:]]'; then
    if printf '%s' "$seg" | grep -Eiq '(-X|--method)[[:space:]=]*(POST|PUT|PATCH)|-XPOST|-XPUT|-XPATCH|(^|[[:space:]])(-F|-f|--field|--raw-field|--input)([[:space:]=]|[^[:space:]-])'; then is_pub=1; fi
  fi
  if [ "$is_pub" = 1 ]; then
    PUBLISH=1
    # Text from a command substitution is scanned only in the form $(cat <one path>); any other $( or backtick
    # (two files, $(< f), $(head f), `cat f`) or a shell variable (set earlier from anything) would reach GitLab unscanned.
    rest="$(printf '%s' "$seg" | sed -E 's/\$\(cat[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:])"'"'"']+)\)//g')"
    case "$rest" in
      *'$('*|*'`'*) block "Text for GitLab may come from a command substitution only as \$(cat <one file>), so the file can be scanned first. Write the text to one scratchpad file and use -m \"\$(cat <file>)\" or --description-file <file>." ;;
    esac
    if printf '%s' "$rest" | grep -Eq '\$([A-Za-z_{]|[0-9@*#?!-])'; then
      block "A GitLab command may not use a shell variable: its value cannot be scanned. Write the literal value in the command, or the text to one scratchpad file and use -m \"\$(cat <file>)\" or --description-file <file>."
    fi
    cands="$(printf '%s' "$seg" | grep -oE -e '--description-file[= ]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' -e '(-F|--field)[ =]*[^[:space:]=]+=@("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' -e '--input[= ]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' -e '\$\(cat[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:])"'"'"']+)' || true)"
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      case "$c" in
        *@*) f="${c#*@}" ;;
        --description-file*) f="${c#--description-file}"; f="${f#[= ]}"; f="${f#"${f%%[![:space:]]*}"}"; f="${f#=}" ;;
        --input*) f="${c#--input}"; f="${f#[= ]}"; f="${f#"${f%%[![:space:]]*}"}" ;;
        '$(cat'*) f="${c#\$(cat}"; f="${f#"${f%%[![:space:]]*}"}"; f="${f#\"}"; f="${f%\"}"; f="${f#\'}"; f="${f%\'}" ;;
        *) f="" ;;
      esac
      [ -n "$f" ] || continue
      rf="$(resolve "$f" "$CUR")" || block "Cannot resolve '$f' to an existing file (missing, or it uses a variable or '-'). Write the text to a scratchpad file first, pass a literal path, then run $PC <file>."
      FILES="$FILES
$rf"
    done <<< "$cands"
  fi
done <<< "$SEGS"

if [ "$PUBLISH" = 1 ]; then
  [ -x "$PC" ] || block "publish-check.sh not found at $PC, so the text cannot be scanned. Reinstall the podbay plugin."
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # Screenshot and video uploads are binary; publish-check can't scan them and the command text is still scanned.
    case "$f" in *.png|*.PNG|*.jpg|*.jpeg|*.gif|*.webp|*.mp4|*.mov) continue ;; esac
    out="$("$PC" "$f" 2>&1)"; rc=$?
    case $rc in
      0) ;;
      1) block "publish-check found a possible secret in $f, so nothing goes to GitLab. Remove it and rerun. Report only file:line. $out" ;;
      *) block "publish-check could not scan $f (exit $rc): $out. Fix the file, then retry." ;;
    esac
  done <<< "$FILES"
  out="$("$PC" "$CMDF" 2>&1)"; rc=$?
  out="${out//$CMDF/<command text>}"
  case $rc in
    0) ;;
    1) block "publish-check found a possible secret in the command text itself (inline -m / --description). Write the text to a scratchpad file, scan it, and pass --description-file. $out" ;;
    *) block "publish-check could not scan the command text (exit $rc): $out" ;;
  esac

  # 6. private references
  [ -x "$PR" ] || block "private-ref-check.sh not found at $PR, so the text cannot be scanned. Reinstall the podbay plugin."
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in *.png|*.PNG|*.jpg|*.jpeg|*.gif|*.webp|*.mp4|*.mov) continue ;; esac
    out="$("$PR" "$f" 2>&1)"; rc=$?
    case $rc in
      0) ;;
      1) block "Private reference in $(printf '%s\n' "$out" | grep -m1 ':[0-9]*: ' | sed -E 's/^(.*:[0-9]+): (.*)$/\1 (\2)/'). $PRIV_HINT" ;;
      *) block "private-ref-check could not scan $f (exit $rc): $out. Fix the file, then retry." ;;
    esac
  done <<< "$FILES"
  # Drop file-path arguments first, so a scratch file name such as f13-issue.md is not flagged.
  Q="'"; P="(\"[^\"]+\"|$Q[^$Q]+$Q|[^[:space:]]+)"
  sed -E -e "s/--description-file[= ]+$P//g" -e "s/--input[= ]+$P//g" -e "s/[A-Za-z0-9_.-]+=@$P//g" \
         -e "s/(^|[[:space:]])-R[= ]*$P//g" "$CMDF" > "$TMP/stripped.txt"
  out="$("$PR" "$TMP/stripped.txt" 2>&1)"; rc=$?
  out="${out//$TMP\/stripped.txt/<command text>}"
  case $rc in
    0) ;;
    1) block "Private reference in $(printf '%s\n' "$out" | grep -m1 ':[0-9]*: ' | sed -E 's/^(.*:[0-9]+): (.*)$/\1 (\2)/'). $PRIV_HINT" ;;
    *) block "private-ref-check could not scan the command text (exit $rc): $out" ;;
  esac
fi

# 9. uploads: a file sent to GitLab always goes to the person's permission prompt (ask_upload). Checked last, on the
#    whole command with line continuations joined (an upload split over lines or with & in its URL is still seen),
#    so every block above still wins; never auto-allowed. Any glab api or curl call to /uploads or
#    /wikis/attachments asks, whatever its flags (a rare GET gets a needless prompt; a missed upload costs more).
J="${CMD//$'\\\n'/}"
J="${J%\\}"
CMDW='(^|[[:space:];&|(`])'
GL="${CMDW}([^[:space:]]*/)?glab[[:space:]]"
if printf '%s' "$J" | grep -Eq "$GL" && printf '%s' "$J" | grep -Eq '(^|[[:space:]])--attach([[:space:]=]|$)'; then ask_upload; fi
if printf '%s' "$J" | grep -Eq "${GL}([^;&|]*[[:space:]])?release[[:space:]]+(upload|create)([[:space:]]|$)"; then ask_upload; fi
if printf '%s' "$J" | grep -Eq "(${GL}([^;&|]*[[:space:]])?api|${CMDW}([^[:space:]]*/)?curl)[[:space:]]" &&
   printf '%s' "$J" | grep -Eq '/(uploads|wikis/attachments)/?([?[:space:]"'"'"'>&;|)]|$)'; then
  ask_upload
fi
# curl with a form or POST to a GitLab API URL whose path uses a shell variable: the endpoint cannot be read.
if printf '%s' "$J" | grep -Eq "${CMDW}([^[:space:]]*/)?curl[[:space:]]" && printf '%s' "$J" | grep -Eq '/api/v4/[^[:space:]]*\$' &&
   printf '%s' "$J" | grep -Eq '(^|[[:space:]])(-[A-Za-z]*F|--form|--data[a-z-]*|-d)([[:space:]=]|[^[:space:]-])|(-X|--request)[[:space:]=]*(POST|post)'; then
  ask_upload
fi
exit 0

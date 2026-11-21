#!/bin/bash
# pb-guard.sh: Claude Code PreToolUse hook (Bash tool only) that makes the podbay plugin's "never" rules deterministic.
# Source of the rules: reference/contract.md (Merge requests, Writing and publishing, Gates), reference/preflight.md (Notes).
# Sibling scripts (publish-check.sh, private-ref-check.sh) are resolved from this script's own directory.
# Exit 0 = allow. Exit 2 = block, with the reason and the allowed route on stderr.
# Blocks:
#   1. cargo fmt / rustfmt anywhere in the command (main is not rustfmt-formatted).
#   2. git push with --force, -f, --force-with-lease, +refspec, --all or --mirror.
#   3. git push to main or master. Allowed only when env PB_KIT_REPO is set to a repo path and the push targets that repo (git -C <path> inside it, or cd into it first). Unset: never allowed.
#   4. glab mr merge, glab mr approve, glab api calls to /merge or /approve endpoints. Merge is allowed only into a target that is not main, master or release/*, read from glab mr view; unsure -> block (Gate 2).
#   5. Publishing to GitLab without a secret scan: glab issue|mr create|note|update and glab api with a non-GET method or
#      field flags. Runs scripts/publish-check.sh on each --description-file / -F key=@file / --input file, and on the whole
#      command text (inline -m / --description). Match, missing file, unresolvable path or scanner error -> block.
#   6. Private references in that same text (finding ids, triage file names, review artifact, gate or grilling words, internal
#      labels): scripts/private-ref-check.sh on the same files and on the command text with file-path arguments removed.
#   7. cargo build|test|clippy|run and pb-ci.sh when free disk is under PB_DISK_FLOOR_GB (default 10). PB_FREE_GB_OVERRIDE fakes free space, for tests.
# File paths may use $VAR or ${VAR} set earlier in the same command with a plain value (S=/tmp/x; export S=...).
# Compound commands are split on && || ; | & and newlines; each piece is checked. Parsing is loose and errs toward blocking.
# A bare `git push` (or `git push <remote> HEAD`) is checked against the target checkout's current branch.
# Not enforced: wrappers (bash script.sh, eval, $(...)), curl or python calls to the API.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# The "may push to main" exception exists only when PB_KIT_REPO names an existing directory.
KIT_REPO=""
if [ -n "${PB_KIT_REPO:-}" ] && [ -d "$PB_KIT_REPO" ]; then KIT_REPO="$(cd "$PB_KIT_REPO" && pwd -P)"; fi
PC="$HERE/publish-check.sh"
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
' "$CMDF" 2>/dev/null)" || exit 0
TOOL="$(printf '%s\n' "$meta" | sed -n 1p)"
CWD="$(printf '%s\n' "$meta" | sed -n 2p)"
[ "$TOOL" = "Bash" ] || exit 0
[ -n "$CWD" ] || CWD="$PWD"
CMD="$(cat "$CMDF")"
[ -n "$CMD" ] || exit 0

PRIV_HINT="GitLab readers can't see the triage notes: rewrite in plain terms (no finding ids, triage file names, review artifact, gate or grilling words, internal labels)."

block() {
  printf 'pb-guard: BLOCKED. %s\n' "$1" >&2
  exit 2
}

# Variables the guard may read in GitLab file paths, from the whole command at once, one "NAME<TAB>value" per line.
# A name counts only when the command sets it exactly once, as a plain NAME=value (or export NAME=value) at the start
# of the command or right after ";" or a newline, followed by ";", "&&", a newline or the end, before any use, and the
# name appears nowhere else as a bare word (no +=, declare, read, printf -v, for, unset, second assignment). No variable
# counts in a command with a heredoc. The value may use only names accepted before it; a tab, $(...) or backtick drops it.
# A line "!HOME" means the command assigns HOME, so ~ and $HOME are not read in file paths.
read -r -d '' VARS_PY <<'PY'
import re, sys
cmd = open(sys.argv[1]).read(); home = sys.argv[2]
N = r'[A-Za-z_][A-Za-z0-9_]*'
if re.search(r'(?<![\w$])HOME(?=\+?=)', cmd):
    print('!HOME'); home = None
if '<<' in cmd:
    sys.exit(0)
assign = re.compile(r'(?:^|(?<=[;\n]))[ \t]*(?:export[ \t]+)?(' + N + r')=("[^"\n]*"|\'[^\'\n]*\'|[^\s;&|"\'<>()`]*)(?=[ \t]*(?:;|&&|\n|$))')
accepted = {}
for m in assign.finditer(cmd):
    name, raw = m.group(1), m.group(2)
    if name == 'HOME' or name in accepted:
        continue
    bare = [b for b in re.finditer(r'(?<![\w$])(?<!\$\{)' + name + r'(?!\w)', cmd)]
    if len(bare) != 1 or bare[0].start() != m.start(1):
        continue
    first_use = re.search(r'\$\{?' + name + r'(?!\w)', cmd)
    if first_use and first_use.start() < m.end():
        continue
    if raw.startswith("'"):
        val = raw[1:-1]
    else:
        val = raw[1:-1] if raw.startswith('"') else raw
        if '`' in val or '$(' in val:
            continue
        if not raw.startswith('"') and (val == '~' or val.startswith('~/')):
            if home is None:
                continue
            val = home + val[1:]
        ok = True
        def sub(mm):
            global ok
            n = mm.group(1) or mm.group(2)
            if n in accepted:
                return accepted[n]
            if n == 'HOME' and home is not None:
                return home
            ok = False
            return ''
        val = re.sub(r'\$(?:\{(' + N + r')\}|(' + N + r'))', sub, val)
        if not ok or '$' in val:
            continue
    if '\t' in val or '\n' in val:
        continue
    accepted[name] = val
for k, v in accepted.items():
    print(k + '\t' + v)
PY
VARS="$(python3 -c "$VARS_PY" "$CMDF" "$HOME" 2>/dev/null)"
VAR_RE='^([^$]*)\$(\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))(.*)$'
# expand_vars <text>: replace $NAME and ${NAME} with accepted values (or HOME); fail on any other variable.
expand_vars() {
  local s="$1" out="" name val
  while [[ "$s" =~ $VAR_RE ]]; do
    name="${BASH_REMATCH[3]:-${BASH_REMATCH[4]}}"
    out+="${BASH_REMATCH[1]}"; s="${BASH_REMATCH[5]}"
    val="$(printf '%s\n' "$VARS" | awk -F'\t' -v n="$name" '$1 == n { v = $2; f = 1 } END { if (f) print v; else exit 1 }')" || {
      if [ "$name" = HOME ] && ! printf '%s\n' "$VARS" | grep -qx '!HOME'; then val="$HOME"; else return 1; fi; }
    out+="$val"
  done
  printf '%s' "$out$s"
}
VAR_FIX="Use a literal path, or set the variable once, earlier in the same command, with a plain value: S=/path/to/scratch; glab mr create ... --description-file \"\$S/body.md\". Values from \$(...), backticks, other environment variables, heredoc commands, or a variable set or changed more than once cannot be checked."

# resolve_pub <path> <base>: like resolve, for GitLab file arguments: also reads the accepted variables above.
# A single-quoted path is literal in bash, so it is never expanded.
resolve_pub() {
  local p="$1" base="$2"
  case "$p" in \'*) resolve "$p" "$base"; return ;; esac
  p="${p%\"}"; p="${p#\"}"
  case "$p" in "~"|"~/"*) printf '%s\n' "$VARS" | grep -qx '!HOME' && return 1 ;; esac
  case "$p" in "~") p="$HOME" ;; "~/"*) p="$HOME/${p#\~/}" ;; esac
  case "$p" in *'`'*|*'$('*) return 1 ;; esac
  p="$(expand_vars "$p")" || return 1
  resolve "$p" "$base"
}

# resolve <path> <base>: print the absolute physical path, or fail if it has variables or does not exist.
# Used as is for cd and git -C (the push-to-main exception), so it reads no command variables.
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

in_kit() { [ -n "$KIT_REPO" ] || return 1; case "$1" in "$KIT_REPO"|"$KIT_REPO"/*) return 0 ;; esac; return 1; }

# 1. rustfmt
if printf '%s' "$CMD" | grep -Eq '(^|[^[:alnum:]_-])(cargo[[:space:]]+(\+[^[:space:]]+[[:space:]]+)?fmt|rustfmt)([^[:alnum:]_-]|$)'; then
  block "cargo fmt / rustfmt is never run here: main is not rustfmt-formatted and reformatting creates churn. Match the surrounding style by hand; check with clippy and cargo test --locked."
fi

SEGS="$(printf '%s' "$CMD" | sed -E 's/(&&|\|\||;|\||&)/\
/g')"

PUBLISH=0
FILES=""
CUR="$CWD"

while IFS= read -r seg; do
  seg="${seg#"${seg%%[![:space:]]*}"}"; seg="${seg#\(}"
  [ -n "$seg" ] || continue

  # 7. disk floor for cargo builds and pb-ci, counted only in command position (after VAR=x, env, time, nice)
  CMDPOS='^(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|env|time|nice|command|exec)[[:space:]]+)*'
  if [[ "$seg" =~ ${CMDPOS}cargo[[:space:]]+(\+[^[:space:]]+[[:space:]]+)?(build|test|clippy|run|check|nextest|b|t|r|c)([[:space:]]|$) ]] || [[ "$seg" =~ ${CMDPOS}((bash|sh|zsh)[[:space:]]+)?[^[:space:]]*pb-ci\.sh([[:space:]]|$) ]]; then
    floor="${PB_DISK_FLOOR_GB:-10}"
    case "$floor" in ''|*[!0-9]*) floor=10 ;; esac
    where="$(printf '%s\n' "$VARS" | awk -F'\t' '$1 == "CARGO_TARGET_DIR" { print $2 }')"
    [ -n "$where" ] || where="${CARGO_TARGET_DIR:-$CUR}"
    if [[ "$seg" =~ CARGO_TARGET_DIR=(\"[^\"]+\"|\'[^\']+\'|[^[:space:]]+) ]]; then
      w="${BASH_REMATCH[1]}"; w="${w//\"/}"; w="${w//\'/}"; w="$(expand_vars "$w")" && where="$w"
    fi
    case "$where" in /*) ;; *) where="$CUR/$where" ;; esac
    while [ ! -e "$where" ] && [ "$where" != / ]; do where="$(dirname "$where")"; done
    free_kb=""
    case "${PB_FREE_GB_OVERRIDE:-}" in
      '') free_kb="$(df -Pk "$where" 2>/dev/null | awk 'NR == 2 { print $4 }')" ;;
      *[!0-9]*) free_kb="" ;;
      *) free_kb=$(( PB_FREE_GB_OVERRIDE * 1048576 )) ;;
    esac
    case "$free_kb" in ''|*[!0-9]*) free_kb="" ;; esac
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
  if [[ "$seg" =~ (^|[[:space:]])git[[:space:]]+(.*[[:space:]])?push([[:space:]]|$) ]]; then
    rest="${seg#* push}"; rest="${rest//\"/}"; rest="${rest//\'/}"
    if printf '%s' "$rest" | grep -Eq '(^|[[:space:]])(--force[a-z-]*|--all|--mirror|-[a-zA-Z]*f[a-zA-Z]*|\+[^[:space:]]+)([[:space:]=]|$)'; then
      block "git push with --force, -f, --force-with-lease, +refspec, --all or --mirror is never allowed. Push the branch normally (git push -u origin <branch>) and let a person handle history."
    fi
    target="$CUR"
    if [[ "$seg" =~ (^|[[:space:]])-C[[:space:]]*(\"[^\"]+\"|\'[^\']+\'|[^[:space:]]+) ]]; then
      target="$(resolve "${BASH_REMATCH[2]}" "$CUR")" || target=""
    fi
    to_main=0
    if printf '%s' "$rest" | grep -Eq '(^|[[:space:]:])(refs/heads/)?(main|master)([[:space:]]|$)'; then
      to_main=1
    else
      # No main/master named: a bare push, or a HEAD refspec, pushes the current branch.
      args="$(set -f; printf '%s\n' $rest | grep -v '^-')"
      if [ "$(printf '%s\n' "$args" | grep -c .)" -lt 2 ] || [ "$(printf '%s\n' "$args" | sed -n 2p)" = HEAD ]; then
        case "$(git -C "${target:-$CUR}" symbolic-ref --short -q HEAD 2>/dev/null)" in main|master) to_main=1 ;; esac
      fi
    fi
    if [ "$to_main" = 1 ] && ! { [ -n "$target" ] && in_kit "$target"; }; then
      block "git push to main or master is never allowed (Gate 2: a person merges). Push a branch (git push -u origin fix/issue-<n>-<slug>) and open an MR. Main is pushable only in the repo named by env PB_KIT_REPO, if set."
    fi
  fi

  # 4. glab merge / approve
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?mr[[:space:]]+approve([[:space:]]|$)'; then
    block "glab mr approve is never allowed (Gate 2: a person approves every MR). Leave the MR open and report its URL."
  fi
  # Merge is allowed only into a branch that is not main, master or release/* (for example an
  # epic's feat/<name>). The target comes from `glab mr view <n> --output json`; unsure -> block.
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?mr[[:space:]]+merge([[:space:]]|$)'; then
    margs="${seg#*mr merge}"; margs="${margs//\"/}"; margs="${margs//\'/}"
    mrid="$(set -f; printf '%s\n' $margs | grep -E '^!?[0-9]+$' | head -1)"; mrid="${mrid#!}"
    mrepo=""
    if [[ "$seg" =~ (^|[[:space:]])(-R|--repo)[[:space:]=]+([^[:space:]]+) ]]; then mrepo="${BASH_REMATCH[3]}"; fi
    [ -n "$mrid" ] || block "glab mr merge needs an explicit MR number, so the guard can check its target branch (Gate 2: a person merges into main and release/*)."
    mtarget="$(cd "$CUR" 2>/dev/null && glab mr view "$mrid" ${mrepo:+-R "$mrepo"} --output json 2>/dev/null |
      python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("target_branch") or "")
except Exception: print("")' 2>/dev/null)"
    case "$mtarget" in
      "") block "glab mr merge: could not read the target branch of MR !$mrid, so it is blocked (Gate 2: a person merges into main and release/*)." ;;
      main|master|release/*) block "glab mr merge into $mtarget is never allowed (Gate 2: a person merges into main and release/*). Leave the MR open and report its URL." ;;
    esac
  fi
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?api[[:space:]]' &&
     printf '%s' "$seg" | grep -Eq '/(merge|approve|unapprove)([^[:alnum:]_-]|$)'; then
    block "glab api calls to /merge or /approve endpoints are never allowed (Gate 2: a person merges and approves every MR)."
  fi

  # 5. publishing
  is_pub=0
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?(issue|mr)[[:space:]]+(create|note|update)([[:space:]]|$)'; then is_pub=1; fi
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])glab[[:space:]]([^;&|]*[[:space:]])?api[[:space:]]'; then
    if printf '%s' "$seg" | grep -Eiq '(-X|--method)[[:space:]=]*(POST|PUT|PATCH)|-XPOST|-XPUT|-XPATCH|(^|[[:space:]])(-F|-f|--field|--raw-field|--input)([[:space:]=]|[^[:space:]-])'; then is_pub=1; fi
  fi
  if [ "$is_pub" = 1 ]; then
    PUBLISH=1
    cands="$(printf '%s' "$seg" | grep -oE -e '--description-file[= ]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' -e '(-F|--field)[ =]*[^[:space:]=]+=@("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' -e '--input[= ]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' || true)"
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      case "$c" in
        *@*) f="${c#*@}" ;;
        --description-file*) f="${c#--description-file}"; f="${f#[= ]}"; f="${f#"${f%%[![:space:]]*}"}"; f="${f#=}" ;;
        --input*) f="${c#--input}"; f="${f#[= ]}"; f="${f#"${f%%[![:space:]]*}"}" ;;
        *) f="" ;;
      esac
      [ -n "$f" ] || continue
      rf="$(resolve_pub "$f" "$CUR")" || block "Cannot resolve '$f' to an existing file (missing, '-', or a variable the guard cannot read). Write the text to a scratchpad file first and check it with $PC <file>. $VAR_FIX"
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
exit 0

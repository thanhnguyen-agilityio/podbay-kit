#!/bin/bash
# Find references to the triage notes in text that is about to reach GitLab: finding ids (f13), ticket ids
# (t1, T2), feature ids (F-CLN-03), review artifact, internal file names, internal labels, gate and grilling words. GitLab readers cannot see the triage notes,
# so these mean nothing to them. Prints <file>:<line>: <rule> per hit (never the matched text).
# Exit 0: clean. Exit 1: match found. Exit 2: bad usage, or a file it cannot scan (unreadable, binary).
# Usage: private-ref-check.sh <file> [<file> ...]
set -u
[ "$#" -gt 0 ] || { echo "usage: private-ref-check.sh <file> [<file> ...]" >&2; exit 2; }

NA='[^[:alnum:]]'
found=0
# rule <name> <grep flags: E or iE> <pattern>: reads the f32/f64-stripped text on stdin, prints one line per hit.
rule() { printf '%s\n' "$TEXT" | LC_ALL=C grep -an"$2" -e "$3" | cut -d: -f1 | while read -r n; do echo "$F:$n: $1"; done; }

for F in "$@"; do
  [ -f "$F" ] && [ -r "$F" ] || { echo "private-ref-check: cannot read $F, stop" >&2; exit 2; }
  if [ "$(LC_ALL=C tr -d '\000' <"$F" | wc -c)" -ne "$(wc -c <"$F")" ]; then
    echo "private-ref-check: $F is binary or UTF-16, stop" >&2
    exit 2
  fi
  # Blank out the Rust float types f32 and f64 (twice, so "f32 f64" is covered); line numbers stay the same.
  TEXT="$(LC_ALL=C sed -E -e "s/(^|$NA)f(32|64)($NA|\$)/\1 \3/g" -e "s/(^|$NA)f(32|64)($NA|\$)/\1 \3/g" "$F")"
  out="$({
    rule 'finding id' E "(^|$NA)f[0-9]{1,3}($NA|\$)"
    rule 'ticket id' E "(^|$NA)[tT][0-9]{1,2}($NA|\$)"
    rule 'feature id' E 'F-[A-Z]{3}-[0-9]{2}'
    rule 'review artifact' iE 'review artifact'
    rule 'finding number' iE 'finding #[0-9]'
    rule 'claude.ai link' E 'claude\.ai/'
    rule 'notes file' E 'ui-ux-issues|preflight(-podbay)?\.md|contract\.md|lessons\.md|rust-glossary|run-report|\.podbay/|triage/[0-9]{4}'
    rule 'internal label' E 'verify::|pb::triaged'
    rule 'gate word' iE "(^|$NA)gate[ -]?[12]($NA|\$)"
    rule 'grilling word' iE 'grill'
    rule 'verification level' iE 'verification level'
  } | sort -t: -k2,2n)"
  [ -z "$out" ] || { printf '%s\n' "$out"; found=1; }
done
[ "$found" = 0 ] && echo "private-ref-check: clean" || echo "private-ref-check: MATCH, stop"
exit "$found"

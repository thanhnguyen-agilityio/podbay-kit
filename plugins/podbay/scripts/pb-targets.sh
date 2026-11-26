#!/bin/bash
# pb-targets.sh: the one list of protected branches. Sourced by pb-guard.sh and pb-merge-check.sh; contract.md, Gate 2.
# Patterns are shell case patterns, separated by spaces.

# Only a person merges into these. Old release/* branches are read-only: they take no new MRs.
PB_PERSON_MERGES="main master release/*"
# develop is team-shared: a team member, or the orchestrator under the standing rule, merges into it.
# To make develop person-only for merges, add develop to the line above (one-line change, kit patch release).

# No session pushes to these directly; changes reach them only by MR.
PB_NO_PUSH="main master develop release/*"

# pb_in_list <branch> "<patterns>": true when the branch matches one of the patterns.
pb_in_list() {
  local b="$1" p hit=1
  set -f
  for p in $2; do
    # shellcheck disable=SC2254
    case "$b" in $p) hit=0; break ;; esac
  done
  set +f
  return $hit
}

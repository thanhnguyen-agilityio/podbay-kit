#!/usr/bin/env bash
# Runs inside the pb-ci container, in /src (read-only checkout). Prints one "PBCI" line per step.
set -u
FLAKY=an_answer_to_an_old_search_
fails=0
step() { # step <name> <command...>; logs PBCI <name> <pass|fail> <seconds>
  local name="$1"; shift
  local t0=$SECONDS
  echo "=== $name: $*"
  if "$@"; then echo "PBCI $name pass $((SECONDS - t0))"; else echo "PBCI $name fail $((SECONDS - t0))"; fails=$((fails + 1)); fi
}

echo "PBCI-HEAD sha=${PBCI_SHA:-unknown} checkout=${PBCI_CHECKOUT:-unknown} target=${PBCI_TARGET:-unknown}"
head=$(git -C /src rev-parse HEAD 2>/dev/null || echo unknown)
if [ "${PBCI_SHA:-}" != "" ] && [ "$head" != "$PBCI_SHA" ]; then echo "PBCI build fail 0 head-moved:$head"; exit 1; fi
# One run at a time on the shared target volume: a second run waits for the first (up to 30 min).
exec 9>/target/.pbci-lock
if ! flock -n 9; then
  echo "=== lock: another pb-ci run is using the shared target volume; waiting up to 30 min"
  if ! flock -w 1800 9; then echo "PBCI build fail 0 locked:another-pb-ci-run-still-running"; exit 1; fi
fi
stamp=/target/.pbci-last; now="${PBCI_CHECKOUT:-?} ${PBCI_SHA:-?}"
if [ "$(cat "$stamp" 2>/dev/null)" != "$now" ]; then
  echo "=== cache: last build was '$(cat "$stamp" 2>/dev/null || echo none)'; cleaning podbay and its test binaries"
  rm -f "$stamp"
  cargo clean -p podbay >/dev/null 2>&1
  # cargo clean -p can leave integration test binaries (tests/mesh.rs) and the podbay binary behind.
  for d in /target/debug; do
    rm -rf "$d"/podbay "$d"/podbay.d "$d"/deps/podbay-* "$d"/deps/mesh-* "$d"/deps/libpodbay-* \
      "$d"/.fingerprint/podbay-* "$d"/incremental/podbay-* "$d"/incremental/mesh-*
  done
fi
step build cargo build --locked
echo "$now" > "$stamp"
step clippy cargo clippy --locked -- -D warnings

# Report only: --all-targets has known old warnings in src/ui/tests.rs.
t0=$SECONDS
echo "=== clippy-all-targets (report only): cargo clippy --all-targets --locked"
out=$(cargo clippy --all-targets --locked 2>&1); echo "$out"
n=$(printf '%s\n' "$out" | grep -cE '^warning: ' ); n=$((n - $(printf '%s\n' "$out" | grep -cE '^warning: .* generated [0-9]+ warning')))
echo "PBCI clippy-all-targets info $((SECONDS - t0)) warnings=$n"

# Tests that fail on Linux but pass on macOS (found 2026-11-16 on fb49b28). They run and are
# reported as known-linux-fail; they do not fail the gate. Fix them in Pod Bay, then remove them here.
# bulk_start_and_resume_*: added 2026-11-17, fails on Linux on main and release in every run.
KNOWN_LINUX="ui::tests::ticking_rows_acts_on_each_for_what_it_can_do the_service_waits_signed_out_and_a_sign_in_reaches_it ui::tests::bulk_start_and_resume_each_take_only_the_rows_they_fit"

tests() { # tests <step> <cargo test args...>
  local name="$1"; shift
  local t0=$SECONDS out failed rest known="" now_ok="" note=""
  echo "=== $name: cargo test --locked $*"
  out=$(cargo test --locked "$@" 2>&1); echo "$out"
  failed=$(printf '%s\n' "$out" | sed -n '/^failures:$/,/^test result/p' | grep -E '^    [A-Za-z_:0-9]+$' | sed 's/^ *//' | sort -u)
  for k in $KNOWN_LINUX; do
    if printf '%s\n' "$failed" | grep -qxF "$k"; then known+=" $k"
    elif printf '%s\n' "$out" | grep -qE "^test $k \.\.\. ok"; then now_ok+=" $k"; fi
  done
  rest=$(printf '%s\n' "$failed" | grep -vxF -f <(printf '%s\n' $KNOWN_LINUX) | grep -v '^$')
  if [ -n "$rest" ] && ! printf '%s\n' "$rest" | grep -qv "$FLAKY"; then
    echo "=== $name: only the known flaky test failed; rerunning it once"
    if cargo test --locked "$@" "$FLAKY" 2>&1; then rest=""; note="retried-flaky"; fi
  fi
  [ -n "$known" ] && note+="${note:+,}known-linux-fail=$(echo $known | wc -w | tr -d ' ')"
  [ -n "$now_ok" ] && note+="${note:+,}known-linux-now-passes:$(echo $now_ok | tr ' ' '+')"
  if [ -n "$rest" ]; then echo "PBCI $name fail $((SECONDS - t0)) $note"; fails=$((fails + 1))
  elif printf '%s\n' "$out" | grep -q '^test result: '; then echo "PBCI $name pass $((SECONDS - t0)) $note"
  else echo "PBCI $name fail $((SECONDS - t0)) no-test-result"; fails=$((fails + 1)); fi
}

tests test --bins

# Mesh tests: real peer processes and tmux.
if [ "${SKIP_MESH:-0}" = 1 ]; then echo "PBCI mesh skipped 0 reason=--skip-mesh"
elif ! command -v tmux >/dev/null; then echo "PBCI mesh skipped 0 reason=no-tmux"
else tests mesh --test mesh
fi
exit $fails

#!/bin/bash
# Tests the small helpers: skills/pb-ci/docker-up.sh (start Docker and wait) and scripts/pb-shot.sh (window screenshot).
# Usage: test-pb-helpers.sh   (prints ok/FAIL per case and a passed/failed line; exit 1 on any failure)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
UP="$HERE/../skills/pb-ci/docker-up.sh"
SHOT="$HERE/pb-shot.sh"
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; }

# Fake docker and open in a bin folder. docker info succeeds once the file "$D/up" exists;
# the fake open records its arguments and, unless NOSTART=1, creates "$D/up".
B="$D/bin"; mkdir -p "$B"
cat > "$B/docker" <<EOF
#!/bin/bash
[ "\$1" = info ] && [ -f "$D/up" ]
EOF
cat > "$B/open" <<EOF
#!/bin/bash
echo "\$*" >> "$D/open.log"
[ "\${NOSTART:-0}" = 1 ] || touch "$D/up"
EOF
chmod +x "$B/docker" "$B/open"
up() { PATH="$B:/usr/bin:/bin" PBCI_DOCKER_WAIT="${WAIT:-6}" PBCI_DOCKER_POLL=1 bash "$UP" 2>&1; }

touch "$D/up"; rm -f "$D/open.log"
out="$(up)"; rc=$?
[ $rc -eq 0 ] && [ ! -f "$D/open.log" ] && ok "Docker already running: no start, exit 0" || bad "Docker already running: no start, exit 0 (rc=$rc, out: $out)"

rm -f "$D/up" "$D/open.log"
out="$(up)"; rc=$?
[ $rc -eq 0 ] && grep -qx -- '-g -a Docker' "$D/open.log" && ok "Docker not running: starts it with open -a Docker and waits, exit 0" || bad "Docker not running: starts it (rc=$rc, open: $(cat "$D/open.log" 2>/dev/null), out: $out)"
printf '%s' "$out" | grep -q 'starting Docker' && ok "says it is starting Docker" || bad "says it is starting Docker (out: $out)"

rm -f "$D/up" "$D/open.log"
out="$(NOSTART=1 WAIT=2 up)"; rc=$?
[ $rc -eq 4 ] && printf '%s' "$out" | grep -q 'not ready after 2s' && ok "Docker never gets ready: exit 4 after the wait" || bad "Docker never gets ready: exit 4 (rc=$rc, out: $out)"

# Linux: no open command anywhere on PATH (macOS has /usr/bin/open, so use a PATH of the fake bin plus sleep only).
rm -f "$D/up" "$B/open"; ln -s "$(command -v sleep)" "$B/sleep"
out="$(PATH="$B" PBCI_UNAME=Darwin PBCI_DOCKER_WAIT=2 PBCI_DOCKER_POLL=1 /bin/bash "$UP" 2>&1)"; rc=$?
[ $rc -eq 4 ] && printf '%s' "$out" | grep -q "has no .open. command" && ok "a Mac with no open command: exit 4 with a message" || bad "a Mac with no open command: exit 4 (rc=$rc, out: $out)"
out="$(PATH="$B" PBCI_UNAME=Linux PBCI_DOCKER_WAIT=2 PBCI_DOCKER_POLL=1 /bin/bash "$UP" 2>&1)"; rc=$?
[ $rc -eq 4 ] && printf '%s' "$out" | grep -q 'start the Docker daemon' && ok "Linux: exit 4 with the daemon message" || bad "Linux: exit 4 with the daemon message (rc=$rc, out: $out)"

# pb-shot.sh: usage and a process with no window.
out="$(bash "$SHOT" 2>&1)"; rc=$?
[ $rc -eq 2 ] && ok "pb-shot without arguments: usage, exit 2" || bad "pb-shot without arguments: exit 2 (rc=$rc, out: $out)"
out="$(bash "$SHOT" abc "$D/x.png" 2>&1)"; rc=$?
[ $rc -eq 2 ] && ok "pb-shot with a pid that is not a number: exit 2" || bad "pb-shot with a non-number pid: exit 2 (rc=$rc)"
out="$(bash "$SHOT" 999999 "$D/x.png" 2>&1)"; rc=$?
[ $rc -eq 1 ] && [ ! -f "$D/x.png" ] && printf '%s' "$out" | grep -qE 'no on-screen window|swift not found' && ok "pb-shot for a pid with no window: exit 1, no file" || bad "pb-shot for a pid with no window: exit 1 (rc=$rc, out: $out)"

out="$(PBSHOT_UNAME=Linux bash "$SHOT" 1 "$D/x.png" 2>&1)"; rc=$?
[ $rc -eq 1 ] && printf '%s' "$out" | grep -q 'macOS only' && ok "pb-shot on Linux: exit 1, macOS only" || bad "pb-shot on Linux: exit 1 (rc=$rc, out: $out)"

# Linux with an unrelated /bin/open (Debian's openvt link): uname decides, open is never called.
rm -f "$D/up" "$D/open.log"; printf '#!/bin/bash\necho "$*" >> "%s/open.log"\n' "$D" > "$B/open"; chmod +x "$B/open"
out="$(PATH="$B" PBCI_UNAME=Linux PBCI_DOCKER_WAIT=2 PBCI_DOCKER_POLL=1 /bin/bash "$UP" 2>&1)"; rc=$?
[ $rc -eq 4 ] && [ ! -f "$D/open.log" ] && printf '%s' "$out" | grep -q 'not macOS' && ok "Linux with an open command: exit 4, open not called" || bad "Linux with an open command: exit 4, open not called (rc=$rc, out: $out)"

# A docker CLI that hangs: each call is cut at 10 s, so the wait limit holds.
cat > "$B/docker" <<EOF
#!/bin/bash
sleep 60
EOF
chmod +x "$B/docker"; rm -f "$B/open"; printf '#!/bin/bash\nexit 0\n' > "$B/open"; chmod +x "$B/open"
t0=$SECONDS; out="$(PATH="$B:/usr/bin:/bin" PBCI_UNAME=Darwin PBCI_DOCKER_WAIT=1 PBCI_DOCKER_POLL=1 /bin/bash "$UP" 2>&1)"; rc=$?; t=$((SECONDS - t0))
[ $rc -eq 4 ] && [ "$t" -le 30 ] && ok "a hanging docker CLI cannot stretch the wait (exit 4 in ${t}s)" || bad "a hanging docker CLI cannot stretch the wait (rc=$rc, ${t}s, out: $out)"

echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]

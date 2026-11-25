#!/bin/bash
# Tests the small helpers: skills/pb-ci/docker-up.sh (start Docker and wait), scripts/pb-shot.sh (window screenshot)
# and skills/pb-verify/ui-window-check.sh (tier 3 real-window check; fake osascript, swift and screencapture, real ffmpeg).
# Usage: test-pb-helpers.sh   (prints ok/FAIL per case and a passed/failed line; exit 1 on any failure)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
UP="$HERE/../skills/pb-ci/docker-up.sh"
SHOT="$HERE/pb-shot.sh"
UIW="$HERE/../skills/pb-verify/ui-window-check.sh"
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

# ui-window-check.sh: fakes in their own bin. The fake osascript keeps the dark mode in "$U/dark";
# with NOCHANGE=1 no "set" applies; with STUCK=1 only the first "set" applies (a restore that does not take). The fake screencapture copies "$U/pic.png".
if command -v ffmpeg >/dev/null 2>&1 && command -v ffprobe >/dev/null 2>&1; then
U="$D/uiw"; UB="$U/bin"; mkdir -p "$UB"
cat > "$UB/osascript" <<EOF
#!/bin/bash
echo "\$*" >> "$U/osa.log"
case "\$*" in
  *"get dark mode"*) cat "$U/dark" ;;
  *"set dark mode to "*) a="\$*"; v="\${a##* }"; [ "\${NOCHANGE:-0}" = 1 ] && exit 0; if [ "\${STUCK:-0}" = 1 ] && [ -f "$U/set-once" ]; then exit 0; fi; touch "$U/set-once"; echo "\$v" > "$U/dark" ;;
esac
EOF
cat > "$UB/swift" <<'EOF'
#!/bin/bash
[ "${4:-}" = pre ] && { [ "${OLDWIN:-0}" = 1 ] && echo 1111; exit 0; }
[ "${NOWIN:-0}" = 1 ] && exit 0
if [ "${3:-0}" -gt 0 ]; then echo 4242; elif [ "${NOTITLE:-0}" != 1 ]; then echo 4242; fi
EOF
printf '#!/bin/bash\nexit 0\n' > "$UB/xcrun"
cat > "$UB/screencapture" <<EOF
#!/bin/bash
[ "\${CAPFAIL:-0}" = 1 ] && { echo "could not create image from window"; exit 1; }
cp "$U/settings.json" "$U/seen.json" 2>/dev/null
cp "$U/pic.png" "\${@: -1}"
EOF
chmod +x "$UB"/*
for t in ffmpeg ffprobe plutil od tr awk sed head tail cat cp mkdir rm sleep mktemp touch ls pkill grep; do ln -sf "$(command -v $t)" "$UB/$t"; done
# Pictures 400x300: a light page with dark bars (the bug) and a light page with light bars; the status bar is pink (the "account").
ffmpeg -v error -f lavfi -i color=c=0xE6E6E6:s=400x300 -vf "drawbox=x=0:y=0:w=400:h=56:color=0x282828:t=fill,drawbox=x=0:y=252:w=400:h=48:color=0x282828:t=fill" -frames:v 1 "$U/bug.png"
ffmpeg -v error -f lavfi -i color=c=0x282828:s=400x300 -frames:v 1 "$U/alldark.png"
ffmpeg -v error -f lavfi -i color=c=0x282828:s=400x300 -vf "drawbox=x=0:y=0:w=400:h=56:color=0xD3D3DB:t=fill,drawbox=x=0:y=252:w=400:h=48:color=0xD3D3DB:t=fill" -frames:v 1 "$U/darkbug.png"
ffmpeg -v error -f lavfi -i color=c=0xE6E6E6:s=400x300 -vf "drawbox=x=0:y=0:w=400:h=56:color=0xD3D3DB:t=fill,drawbox=x=0:y=252:w=400:h=48:color=0xFFC8C8:t=fill" -frames:v 1 "$U/good.png"
uiw() { PATH="$UB:/bin" PBUI_UNAME="${UNAME:-Darwin}" /bin/bash "$UIW" "$@" 2>&1; }
reset_ui() { echo false > "$U/dark"; rm -f "$U/osa.log" "$U/set-once" "$U/seen.json"; printf '{"theme":"dark"}\n' > "$U/settings.json"; rm -rf "$U/out"; }
pix() { ffmpeg -v error -i "$1" -vf "crop=1:1:$2:$3" -f rawvideo -pix_fmt rgb24 - | od -An -tu1 | tr "\n" " " | awk '{print $1, $2, $3}'; }

reset_ui
out="$(uiw --title Pod --out "$U/out")"; rc=$?
[ $rc -eq 3 ] && printf '%s' "$out" | grep -q WARNING && [ ! -f "$U/osa.log" ] && ok "ui-window-check without --yes: warns, exit 3, appearance untouched" || bad "ui-window-check without --yes: exit 3 (rc=$rc, out: $out)"

reset_ui
out="$(uiw --yes --title Pod --out "$U/out" --theme light)"; rc=$?
[ $rc -eq 2 ] && ok "ui-window-check --theme without --settings: exit 2" || bad "ui-window-check --theme without --settings: exit 2 (rc=$rc)"

reset_ui
out="$(UNAME=Linux uiw --yes --title Pod --out "$U/out")"; rc=$?
[ $rc -eq 4 ] && printf '%s' "$out" | grep -q 'macOS only' && ok "ui-window-check on Linux: exit 4" || bad "ui-window-check on Linux: exit 4 (rc=$rc, out: $out)"

reset_ui; cp "$U/bug.png" "$U/pic.png"
out="$(uiw --yes --title Pod --out "$U/out" --theme light --settings "$U/settings.json" --start "touch $U/started" --settle 0)"; rc=$?
[ $rc -eq 1 ] && grep -q '^verdict: FAIL' "$U/out/result.txt" && ok "bars darker than the page in Theme Light: FAIL, exit 1" || bad "bars darker than the page: FAIL (rc=$rc, out: $out)"
[ "$(cat "$U/dark")" = false ] && grep -q 'set dark mode to true' "$U/osa.log" && ok "appearance set to Dark during the check and restored after" || bad "appearance restored (now $(cat "$U/dark"); log: $(cat "$U/osa.log"))"
grep -q '"theme":"light"' "$U/seen.json" 2>/dev/null && ok "theme preset is in the settings file during the capture" || bad "theme preset during the capture (seen: $(cat "$U/seen.json" 2>/dev/null))"
grep -q '"theme":"dark"' "$U/settings.json" && [ -f "$U/started" ] && ok "settings file restored and the start command ran" || bad "settings restored and start ran (settings: $(cat "$U/settings.json"))"

reset_ui; cp "$U/good.png" "$U/pic.png"
out="$(uiw --yes --title Pod --out "$U/out" --theme light --settings "$U/settings.json" --settle 0 --blank 0,0,10,10)"; rc=$?
shot="$(ls "$U"/out/*.png 2>/dev/null | head -1)"
[ $rc -eq 0 ] && grep -q '^verdict: PASS' "$U/out/result.txt" && ok "bars that follow Theme Light: PASS, exit 0" || bad "bars that follow Theme Light: PASS (rc=$rc, out: $out)"
[ -n "$shot" ] && [ "$(pix "$shot" 200 290)" = "0 0 0" ] && [ "$(pix "$shot" 5 5)" = "0 0 0" ] && [ "$(pix "$shot" 200 150)" != "0 0 0" ] && ok "saved picture has the status bar and the extra box blanked" || bad "saved picture blanked (shot=$shot, bottom $(pix "$shot" 200 290), box $(pix "$shot" 5 5))"
[ "$(ls "$U/out" | wc -l | tr -d ' ')" = 2 ] && ok "only the blanked picture and result.txt are saved" || bad "only two files saved ($(ls "$U/out"))"

reset_ui
out="$(CAPFAIL=1 uiw --yes --title Pod --out "$U/out" --settle 0)"; rc=$?
[ $rc -eq 4 ] && [ "$(cat "$U/dark")" = false ] && [ ! -d "$U/out" ] && ok "capture fails: exit 4, appearance restored, nothing saved" || bad "capture fails: exit 4 and restored (rc=$rc, dark=$(cat "$U/dark"), out: $out)"

reset_ui
out="$(NOWIN=1 uiw --yes --title Pod --out "$U/out" --wait 1)"; rc=$?
[ $rc -eq 4 ] && [ "$(cat "$U/dark")" = false ] && printf '%s' "$out" | grep -q 'no on-screen window' && ok "no window: exit 4, appearance restored" || bad "no window: exit 4 and restored (rc=$rc, dark=$(cat "$U/dark"), out: $out)"

reset_ui; cp "$U/good.png" "$U/pic.png"
out="$(STUCK=1 uiw --yes --title Pod --out "$U/out" --settle 0)"; rc=$?
[ $rc -eq 5 ] && printf '%s' "$out" | grep -q 'Tell the user' && ok "a restore that does not take: exit 5 with an error" || bad "a restore that does not take: exit 5 (rc=$rc, out: $out)"
reset_ui; cp "$U/alldark.png" "$U/pic.png"
out="$(uiw --yes --title Pod --out "$U/out" --theme light --settings "$U/settings.json" --settle 0)"; rc=$?
[ $rc -eq 1 ] && grep -q 'page is dark' "$U/out/result.txt" && ok "a preset that did not take (all dark, Theme Light): FAIL, not PASS" || bad "all dark with Theme Light: FAIL (rc=$rc, out: $out)"

reset_ui
out="$(uiw --yes --title Pod --out "$U/out" --blank 1,,2,3)"; rc=$?
[ $rc -eq 2 ] && ok "a --blank box with an empty field: exit 2" || bad "a --blank box with an empty field: exit 2 (rc=$rc)"

reset_ui; cp "$U/good.png" "$U/pic.png"; rm -f "$U/start.pid"
out="$(uiw --yes --title Pod --out "$U/out" --settle 0 --start "echo \$\$ > $U/start.pid; exec sleep 300")"; rc=$?
sp="$(cat "$U/start.pid" 2>/dev/null)"
[ -n "$sp" ] && ! kill -0 "$sp" 2>/dev/null && ok "the window started with --start is stopped at the end" || { bad "the started window is stopped (pid ${sp:-none} still running)"; [ -n "$sp" ] && kill "$sp" 2>/dev/null; }

reset_ui; cp "$U/good.png" "$U/pic.png"; rm -f "$U/gc.pid"
# start -> gc1.sh -> gc2.sh (exec sleep): the sleep is a grandchild of the start shell.
printf '/bin/sh %s/gc2.sh; true\n' "$U" > "$U/gc1.sh"; printf 'echo $$ > %s/gc.pid; exec sleep 300\n' "$U" > "$U/gc2.sh"
out="$(uiw --yes --title Pod --out "$U/out" --settle 0 --start "/bin/sh $U/gc1.sh; true")"; rc=$?
gp="$(cat "$U/gc.pid" 2>/dev/null)"
[ -n "$gp" ] && ! kill -0 "$gp" 2>/dev/null && ok "a grandchild of the --start command is stopped too" || { bad "grandchild stopped (pid ${gp:-none} still running)"; [ -n "$gp" ] && kill "$gp" 2>/dev/null; }

reset_ui; cp "$U/good.png" "$U/pic.png"
out="$(NOCHANGE=1 uiw --yes --title Pod --out "$U/out" --theme light --settings "$U/settings.json" --settle 0)"; rc=$?
[ $rc -eq 4 ] && printf '%s' "$out" | grep -q 'did not change' && [ ! -d "$U/out" ] && grep -q '"theme":"dark"' "$U/settings.json" && ok "appearance change refused: exit 4, no verdict, settings restored" || bad "appearance change refused: exit 4 (rc=$rc, out: $out)"

reset_ui
out="$(uiw --yes --title Pod --out "$U/out" --top 1)"; rc=$?
[ $rc -eq 2 ] && ok "--top below 4 px: exit 2" || bad "--top below 4 px: exit 2 (rc=$rc)"

reset_ui; cp "$U/alldark.png" "$U/pic.png"
out="$(uiw --yes --title Pod --out "$U/out" --appearance light --theme dark --settings "$U/settings.json" --settle 0)"; rc=$?
[ $rc -eq 0 ] && grep -q '^verdict: PASS' "$U/out/result.txt" && grep -q 'set dark mode to false' "$U/osa.log" && ok "Theme Dark on macOS Light, dark bars: PASS" || bad "Theme Dark on macOS Light, dark bars: PASS (rc=$rc, out: $out)"

reset_ui; cp "$U/darkbug.png" "$U/pic.png"
out="$(uiw --yes --title Pod --out "$U/out" --appearance light --theme dark --settings "$U/settings.json" --settle 0)"; rc=$?
[ $rc -eq 1 ] && grep -q 'lighter than the page' "$U/out/result.txt" && ok "Theme Dark on macOS Light, light bars: FAIL" || bad "Theme Dark on macOS Light, light bars: FAIL (rc=$rc, out: $out)"

reset_ui; cp "$U/good.png" "$U/pic.png"
out="$(OLDWIN=1 uiw --yes --title Pod --out "$U/out" --theme light --settings "$U/settings.json" --start "sleep 1" --settle 0)"; rc=$?
[ $rc -eq 4 ] && printf '%s' "$out" | grep -q 'already open' && ! grep -q 'set dark' "$U/osa.log" 2>/dev/null && grep -q '"theme":"dark"' "$U/settings.json" && ok "--start with a matching window already open: exit 4 before any change" || bad "--start with an old window open: exit 4 before any change (rc=$rc, out: $out)"

reset_ui; cp "$U/good.png" "$U/pic.png"
out="$(NOTITLE=1 uiw --yes --title Pod --out "$U/out" --start "sleep 30" --settle 0)"; rc=$?
[ $rc -eq 0 ] && ok "with --start the window is found by its process group, even with titles hidden" || bad "window found by process group with titles hidden (rc=$rc, out: $out)"

reset_ui
out="$(NOTITLE=1 uiw --yes --title Pod --out "$U/out" --wait 1)"; rc=$?
[ $rc -eq 4 ] && printf '%s' "$out" | grep -q 'Screen Recording caveat' && ok "no window by title: the message points to the Screen Recording caveat" || bad "no window by title names the caveat (rc=$rc, out: $out)"

reset_ui
( NOWIN=1 PATH="$UB:/bin" PBUI_UNAME=Darwin /bin/bash "$UIW" --yes --title Pod --out "$U/out" --wait 30 >"$U/term.log" 2>&1; echo $? > "$U/term.rc" ) &
bg=$!; sleep 3; pkill -TERM -f "ui-window-check.sh --yes --title Pod --out $U/out --wait 30"; wait "$bg"
[ "$(cat "$U/term.rc")" = 143 ] && [ "$(cat "$U/dark")" = false ] && ok "TERM during the wait: appearance restored, exit 143" || bad "TERM during the wait (rc=$(cat "$U/term.rc"), dark=$(cat "$U/dark"), log: $(cat "$U/term.log"))"
else
  bad "ui-window-check tests need ffmpeg and ffprobe"
fi

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

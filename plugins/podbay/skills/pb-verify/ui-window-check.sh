#!/bin/bash
# Tier 3 of the unattended UI test (references/ui-tiers.md): the real app window, no clicks.
# Presets the theme in the app's settings file, sets the macOS appearance, starts the window, captures it with
# screencapture -l, and compares the bar pixels with the page pixels. The appearance and the settings file are
# restored on every exit (trap), and the saved picture has the account area blanked.
#
# Usage: ui-window-check.sh --yes --title <window title part> --out <dir> [options]
#   --yes              the user agreed that the desktop appearance changes for a short time (without it: warn, exit 3)
#   --title <text>     part of the window title to capture (for example Pod Bay-local-<branch>)
#   --out <dir>        where the blanked picture and result.txt go
#   --appearance dark|light   macOS appearance during the check (default dark)
#   --theme light|dark|system --settings <file>   preset "theme" in the app's settings.json before the start
#   --start <command>  command that starts the window (run in the background after the presets; stopped again, with
#                      its child processes, before the settings file is restored); without it the window must
#                      already be open (an open window may not repaint after the appearance changes)
#   --expect light|dark  theme the bars must follow (default: --theme, else light)
#   --top <px> --bottom <px>   height of the title bar and the status bar in picture pixels (default 56 and 48)
#   --blank x,y,w,h    extra box to blank (picture pixels); repeatable. The bottom bar (plus half its height) is always blanked.
#   --wait <s>         seconds to wait for the window (default 60); --settle <s> before the capture (default 5)
# Env (tests only): PBUI_UNAME overrides uname -s.
# Exit 0 PASS, 1 FAIL (the page or a bar does not follow the theme), 2 bad usage, 3 not confirmed (--yes missing),
#      4 cannot run (not macOS, a tool missing, no window, capture failed), 5 the appearance could not be restored.
set -u
yes=0; title=""; out=""; appear=dark; theme=""; settings=""; start=""; expect=""; top=56; bottom=48; wait_s=60; settle=5
blanks=()
usage() { sed -n '6,22p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) yes=1; shift ;;
    --title|--out|--appearance|--theme|--settings|--start|--expect|--top|--bottom|--blank|--wait|--settle)
      [ $# -ge 2 ] || usage
      case "$1" in
        --title) title="$2" ;; --out) out="$2" ;; --appearance) appear="$2" ;; --theme) theme="$2" ;;
        --settings) settings="$2" ;; --start) start="$2" ;; --expect) expect="$2" ;; --top) top="$2" ;;
        --bottom) bottom="$2" ;; --blank) blanks+=("$2") ;; --wait) wait_s="$2" ;; --settle) settle="$2" ;;
      esac; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$title" ] && [ -n "$out" ] || usage
case "$appear" in dark|light) ;; *) usage ;; esac
case "$theme" in ''|light|dark|system) ;; *) usage ;; esac
[ -z "$theme" ] || [ -n "$settings" ] || { echo "ui-window-check: --theme needs --settings <file>" >&2; exit 2; }
[ -n "$expect" ] || expect="${theme:-light}"; [ "$expect" = system ] && expect="$appear"
case "$expect" in light|dark) ;; *) usage ;; esac
for n in "$top" "$bottom" "$wait_s" "$settle"; do case "$n" in ''|*[!0-9]*) usage ;; esac; done
[ "$top" -ge 4 ] && [ "$bottom" -ge 4 ] || usage
for b in ${blanks[@]+"${blanks[@]}"}; do case "$b" in *[!0-9,]*|*,*,*,*,*|,*|*,|*,,*) usage ;; *,*,*,*) ;; *) usage ;; esac; done

if [ "$yes" != 1 ]; then
  echo "ui-window-check: WARNING: this switches the macOS appearance of the user's real desktop to '$appear' for up to about $((wait_s + settle + 10)) s, then restores it."
  echo "ui-window-check: ask the user first; rerun with --yes after they agree."
  exit 3
fi
[ "${PBUI_UNAME:-$(uname -s 2>/dev/null)}" = Darwin ] || { echo "ui-window-check: macOS only" >&2; exit 4; }
for t in osascript screencapture ffmpeg ffprobe xcrun plutil; do command -v "$t" >/dev/null 2>&1 || { echo "ui-window-check: $t not found" >&2; exit 4; }; done
xcrun --find swift >/dev/null 2>&1 || { echo "ui-window-check: swift not found (xcode-select --install)" >&2; exit 4; }
[ -z "$settings" ] || [ -f "$settings" ] || { echo "ui-window-check: settings file not found: $settings" >&2; exit 4; }

W="$(mktemp -d)"
# find.swift <title part> <pgid>: the largest on-screen window. pgid > 0 matches the window's owner by its process group
# (works even when macOS hides window titles, as it does without the Screen Recording grant); pgid 0 matches the title.
cat > "$W/find.swift" <<'EOF'
import CoreGraphics
import Darwin
let part = CommandLine.arguments[1]
let group = Int32(CommandLine.arguments[2]) ?? 0
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
var best = 0, area = 0.0
for w in list where (w["kCGWindowLayer"] as? Int) == 0 {
  let owner = Int32(w["kCGWindowOwnerPID"] as? Int ?? 0)
  if group > 0 { if getpgid(owner) != group { continue } }
  else if !((w["kCGWindowName"] as? String) ?? "").contains(part) { continue }
  let b = w["kCGWindowBounds"] as? [String: Double] ?? [:]
  let a = (b["Width"] ?? 0) * (b["Height"] ?? 0)
  if a > area { area = a; best = w["kCGWindowNumber"] as? Int ?? 0 }
}
if best > 0 { print(best) }
EOF
# With --start, a window that is already open would be measured instead of the new one: refuse before any change.
if [ -n "$start" ] && [ -n "$(swift "$W/find.swift" "$title" 0 pre 2>/dev/null)" ]; then
  rm -rf "$W"; echo "ui-window-check: a window with '$title' in its title is already open; stop it first (pb-run step 3). Nothing changed." >&2; exit 4
fi
get_dark() { osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>/dev/null; }
set_dark() { osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $1" >/dev/null 2>&1; }
was="$(get_dark)"
case "$was" in true|false) ;; *) rm -rf "$W"; echo "ui-window-check: cannot read the macOS appearance (osascript said: $was)" >&2; exit 4 ;; esac
[ -z "$settings" ] || cp -p "$settings" "$W/settings.bak" || { rm -rf "$W"; echo "ui-window-check: could not back up $settings; nothing changed" >&2; exit 4; }
spid=""
restored=0
restore() {
  trap '' INT TERM HUP  # a second signal must not cut the restore short
  [ "$restored" = 1 ] && return; restored=1
  if [ -n "$spid" ]; then
    # The start command runs in its own process group (set -m): stop the whole group, then KILL what is left.
    kill -TERM -- "-$spid" 2>/dev/null
    local i=0; while kill -0 -- "-$spid" 2>/dev/null && [ "$i" -lt 10 ]; do sleep 0.5; i=$((i + 1)); done
    kill -KILL -- "-$spid" 2>/dev/null
  fi
  if [ -n "$settings" ] && [ -f "$W/settings.bak" ] && ! cp -p "$W/settings.bak" "$settings"; then
    echo "ui-window-check: ERROR: could not restore $settings (the theme preset is still in it). Tell the user at once." >&2
  fi
  set_dark "$was"
  local now; now="$(get_dark)"
  rm -rf "$W"
  if [ "$now" != "$was" ]; then
    echo "ui-window-check: ERROR: the macOS appearance is '$now', not '$was' as before. Tell the user at once." >&2
    exit 5
  fi
  echo "ui-window-check: macOS appearance restored (dark mode $was)."
}
trap 'rc=$?; restore; exit $rc' EXIT
trap 'exit 130' INT; trap 'exit 143' TERM; trap 'exit 129' HUP

echo "ui-window-check: WARNING: the desktop appearance changes to '$appear' now and is restored at the end."
[ -z "$theme" ] || plutil -replace theme -string "$theme" "$settings" || { echo "ui-window-check: could not set theme in $settings" >&2; exit 4; }
if [ "$appear" = dark ]; then want=true; else want=false; fi
set_dark "$want"
[ "$(get_dark)" = "$want" ] || { echo "ui-window-check: the macOS appearance did not change to '$appear' (Automation access to System Events denied, or the setting is managed); no check made" >&2; exit 4; }
if [ -n "$start" ]; then set -m; bash -c "$start" >"$W/start.log" 2>&1 & spid=$!; set +m; fi

wid=""; t0=$SECONDS
while [ $((SECONDS - t0)) -lt "$wait_s" ]; do
  wid="$(swift "$W/find.swift" "$title" "${spid:-0}" 2>"$W/swift.err")"; [ -n "$wid" ] && break; sleep 2
done
if [ -z "$wid" ]; then
  if [ -n "$spid" ]; then echo "ui-window-check: the started process shows no on-screen window after ${wait_s}s. $(head -2 "$W/swift.err" 2>/dev/null)" >&2
  else echo "ui-window-check: no on-screen window with '$title' in its title after ${wait_s}s. If it is open, this session may lack the Screen Recording grant (macOS hides window titles then): see the Screen Recording caveat (reference/contract.md). $(head -2 "$W/swift.err" 2>/dev/null)" >&2; fi
  [ -s "$W/start.log" ] && echo "ui-window-check: start log: $(tail -3 "$W/start.log")" >&2
  exit 4
fi
sleep "$settle"
raw="$W/raw.png"
if ! err="$(screencapture -x -o -l "$wid" "$raw" 2>&1)" || [ ! -s "$raw" ]; then
  echo "ui-window-check: screencapture failed: ${err:-no file written}" >&2
  echo "ui-window-check: see the Screen Recording caveat (reference/contract.md). Ask the user to run: screencapture -x -o -l $wid <out.png>" >&2
  exit 4
fi

# Average colour of one box as "r g b" (ffmpeg scales the box to one pixel).
avg() { ffmpeg -v error -i "$raw" -vf "crop=$1:$2:$3:$4,scale=1:1:flags=area" -f rawvideo -pix_fmt rgb24 - | od -An -tu1 | tr "\n" " " | awk '{print $1, $2, $3}'; }
lum() { echo "$1" | awk '{printf "%d", 0.2126*$1 + 0.7152*$2 + 0.0722*$3}'; }
size="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$raw")"
w="${size%%,*}"; h="${size#*,}"
case "$w$h" in ''|*[!0-9]*) echo "ui-window-check: cannot read the picture size" >&2; exit 4 ;; esac
[ $((top + bottom + 20)) -lt "$h" ] || { echo "ui-window-check: --top and --bottom do not fit a ${h}px picture" >&2; exit 4; }
iw=$((w * 8 / 10)); ix=$((w / 10))
top_c="$(avg "$iw" $((top / 2)) "$ix" $((top / 4)))"
bot_c="$(avg "$iw" $((bottom / 2)) "$ix" $((h - bottom + bottom / 4)))"
page_c="$(avg $((w / 2)) $((h / 4)) $((w / 4)) $(((h - h / 4) / 2)))"
for c in "$top_c" "$bot_c" "$page_c"; do case "$c" in [0-9]*' '[0-9]*' '[0-9]*) ;; *) echo "ui-window-check: could not measure the picture's colours" >&2; exit 4 ;; esac; done
lt="$(lum "$top_c")"; lb="$(lum "$bot_c")"; lp="$(lum "$page_c")"
verdict=PASS; why=""
# The page itself must follow the theme first; otherwise a preset that did not take (all dark) would pass.
if [ "$expect" = light ] && [ "$lp" -lt 128 ]; then verdict=FAIL; why="page is dark, not light (did the theme preset take?);"; fi
if [ "$expect" = dark ] && [ "$lp" -ge 128 ]; then verdict=FAIL; why="page is light, not dark (did the theme preset take?);"; fi
# A bar more than 40 (of 255) darker than the page in a light theme, or lighter in a dark theme, does not follow the theme.
for pair in "title bar:$lt" "status bar:$lb"; do
  name="${pair%%:*}"; l="${pair##*:}"
  if [ "$expect" = light ] && [ $((lp - l)) -gt 40 ]; then verdict=FAIL; why="$why $name darker than the page;"; fi
  if [ "$expect" = dark ] && [ $((l - lp)) -gt 40 ]; then verdict=FAIL; why="$why $name lighter than the page;"; fi
done

# Blank the account area (the bottom bar names the signed-in account) and any extra boxes before anything is saved.
bb=$((bottom + bottom / 2))  # the bottom bar plus a half-bar margin, in case the bar is taller than --bottom
vf="drawbox=x=0:y=$((h - bb)):w=$w:h=$bb:color=black:t=fill"
for b in ${blanks[@]+"${blanks[@]}"}; do IFS=, read -r bx by bw bh <<<"$b"; vf="$vf,drawbox=x=$bx:y=$by:w=$bw:h=$bh:color=black:t=fill"; done
mkdir -p "$out"
shot="$out/window-${appear}-theme-${theme:-unchanged}.png"
ffmpeg -v error -y -i "$raw" -vf "$vf" "$shot" || { echo "ui-window-check: blanking failed; nothing saved" >&2; rm -f "$shot"; exit 4; }
rm -f "$raw"
{
  echo "verdict: $verdict${why:+ (${why# })}"
  echo "macOS appearance: $appear; theme preset: ${theme:-none}; expected bars: $expect"
  echo "luminance (0-255): title bar $lt, status bar $lb, page $lp"
  echo "colours (r g b): title bar $top_c; status bar $bot_c; page $page_c"
  echo "picture: $shot (bottom ${bb}px blanked${blanks[0]+, plus ${#blanks[@]} box(es)})"
} > "$out/result.txt"
cat "$out/result.txt"
[ "$verdict" = PASS ]

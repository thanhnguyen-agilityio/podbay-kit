#!/bin/bash
# Screenshot the largest on-screen window of one process (macOS), without the window shadow.
# Usage: pb-shot.sh <pid> <out.png>   (env PBSHOT_UNAME overrides uname -s, for tests)
# Finds the window id with CoreGraphics (swift, from the Xcode command line tools), then runs screencapture -x -o -l <id>.
# Exit 0 saved, 1 no window or the capture failed, 2 bad usage.
# The capture needs the Screen Recording grant. macOS checks it against the app responsible for the tmux server (the
# terminal that started it), and only for a server started after the grant: an older server, or one started by a service,
# fails with "could not create image from window/display" until the user restarts it from the granted terminal
# (reference/contract.md, Screen Recording caveat). Then report the printed command for the user to run; no workarounds.
set -u
pid="${1:-}"; out="${2:-}"
case "$pid" in ''|*[!0-9]*) echo "usage: pb-shot.sh <pid> <out.png>" >&2; exit 2 ;; esac
[ -n "$out" ] || { echo "usage: pb-shot.sh <pid> <out.png>" >&2; exit 2; }
[ "${PBSHOT_UNAME:-$(uname -s 2>/dev/null)}" = Darwin ] || { echo "pb-shot: macOS only (it uses screencapture)" >&2; exit 1; }
# /usr/bin/swift is a stub that is always there; xcrun finds the real one only when the command line tools are installed.
xcrun --find swift >/dev/null 2>&1 || { echo "pb-shot: swift not found (install the Xcode command line tools: xcode-select --install)" >&2; exit 1; }
case "$out" in /*) ;; *) out="$(pwd -P)/$out" ;; esac
tmp="$(mktemp -t pb-shot)"; src="$tmp.swift"; trap 'rm -f "$tmp" "$src"' EXIT
cat > "$src" <<'EOF'
import CoreGraphics
let pid = Int(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
var best = 0, area = 0.0
for w in list where (w["kCGWindowOwnerPID"] as? Int) == pid && (w["kCGWindowLayer"] as? Int) == 0 {
  let b = w["kCGWindowBounds"] as? [String: Double] ?? [:]
  let a = (b["Width"] ?? 0) * (b["Height"] ?? 0)
  if a > area { area = a; best = w["kCGWindowNumber"] as? Int ?? 0 }
}
if best > 0 { print(best) }
EOF
wid="$(swift "$src" "$pid" 2>"$tmp")"
if [ -z "$wid" ]; then
  if [ -s "$tmp" ]; then echo "pb-shot: the window lookup failed: $(head -3 "$tmp")" >&2
  else echo "pb-shot: no on-screen window for pid $pid (is the window open and not minimized?)" >&2; fi
  exit 1
fi
mkdir -p "$(dirname "$out")"
if ! err="$(screencapture -x -o -l "$wid" "$out" 2>&1)" || [ ! -s "$out" ]; then
  echo "pb-shot: screencapture failed: ${err:-no file written}" >&2
  echo "pb-shot: if it says 'could not create image from window' (or 'from display'), the tmux server this runs under has no Screen Recording grant (see the Screen Recording caveat). Ask the user to run: screencapture -x -o -l $wid $(printf '%q' "$out")" >&2
  exit 1
fi
echo "pb-shot: saved $out (window $wid)"

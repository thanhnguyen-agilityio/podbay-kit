# verify-ticket: recording and ffmpeg recipes

Chrome's gif recorder only sees the browser. Use it only for the GitLab/GitHub side, never for the app.

## Record one scenario

`screencapture -v` cannot be stopped early: SIGINT discards the clip and it ignores stdin. So record with a time limit and trim afterwards.

1. Pick a limit: the scenario's expected length plus 30 seconds (default 120).
2. Start it in the background (Bash `run_in_background`), then operate the app:
   ```bash
   screencapture -v -k -x -V <seconds> "<out>/s<n>.mov"
   ```
   `-k` shows clicks, `-x` no sound. To record only the app window, add `-R x,y,w,h` (points) from the window bounds seen in a screenshot.
3. Note the seconds from start to the last useful frame. When the background task finishes, trim:
   ```bash
   ffmpeg -v error -y -i "<out>/s<n>.mov" -t <seconds> -c copy "<out>/s<n>-trim.mov"
   ```

Before each recording: bring the app to the front, then read its window bounds again (`app_list_windows`); windows move and resize between steps, and `-R` records whatever is on top in that area. Computer-use screenshot coordinates are not screen points: the result names its coordinate frame; `-R` takes points.

Computer-use screenshots hide apps that are not granted, which can include system notification banners. To check for a banner, use `screencapture -x -R<corner>` instead.

Screenshots at key steps: `screencapture -x "<out>/s<n>-<step>.png"`, or save the computer-use screenshot.

Permission probe (step 0): `screencapture -v -x -V 2 <scratchpad>/probe.mov`. Exit 0 and a file with a duration (`ffprobe -v error -show_entries format=duration -of csv=p=0 <file>`) means Screen Recording is granted. Delete the probe after.

## Convert

mp4 (web-safe, no audio, at most 1280 wide):
```bash
ffmpeg -v error -y -i "<in>.mov" -vf "scale='min(1280,iw)':-2,fps=15" \
  -c:v libx264 -preset slow -crf 28 -pix_fmt yuv420p -movflags +faststart -an "<out>/s<n>.mp4"
```

gif (palette for small, clean output):
```bash
ffmpeg -v error -y -i "<out>/s<n>.mp4" \
  -vf "fps=8,scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer" \
  -loop 0 "<out>/s<n>.gif"
```

## Blur personal data

Blur one box (pixels of the file, `x,y` top-left) in a png, mp4 or gif; repeat the filter pair for more boxes:
```bash
ffmpeg -v error -y -i "<in>" -filter_complex "[0]split[a][b];[b]crop=<w>:<h>:<x>:<y>,boxblur=12[c];[a][c]overlay=<x>:<y>" "<out>"
```
Look at the result before using it. When the box moves between frames (scrolling, dialogs), post a still instead of the video.

## Keep every file at most 10 MB

Check: `stat -f %z <file>` (10 MB = 10485760). Shrink in this order and stop when it fits:
1. mp4: `-crf 32`, then `fps=10`, then `scale='min(960,iw)':-2`.
2. gif: `fps=6`, then `scale=640:-1`, then `max_colors=64`, then keep only the key part with `-ss <start> -t <length>`.
3. Still too big: keep the mp4, drop the gif, and say so in results.md.

Delete the `.mov` files after conversion; they are large and not posted.

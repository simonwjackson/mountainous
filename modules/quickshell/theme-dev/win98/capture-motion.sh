#!/usr/bin/env bash
# Filmstrips of the window motion (window-motion.js), from the real
# Desktops' motion layers in private headless sway sessions (session.sh):
# each move held at frames 0 to 8 (the motion IPC's hold), between a cell
# before it and a cell after it, with a stand-in app window under the
# chrome. Both themes, light and dark. Development only, never delivered.
#
#   modules/quickshell/theme-dev/win98/capture-motion.sh <shell dir> <out dir>
#
# Writes <out>/<theme>-<mode>/<move>-{before,k0..k8,after}.png and
# <out>/<theme>-<mode>-<move>.filmstrip.png (11 cells: before, 0 ms ... 133 ms,
# after). Needs sway, grim, qs and python3 with Pillow on PATH.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
out=$(realpath -m "${2:?out dir}")
mkdir -p "$out"

# A held frame k: GlancePlan.frameAt floors t / (1000 / 60); one ms past
# each boundary.
hold_ms() { if [ "$1" = 0 ]; then echo 0; else echo $(( $1 * 1000 / 60 + 1 )); fi; }

film() {  # film <name> <motion json> <app before> <app during> <app after>
  local name=$1 ev=$2 before=$3 during=$4 after=$5 dir=$6 k
  w98 motionHold -1 >/dev/null; sleep 0.4
  w98 app "$before" >/dev/null; sleep 0.6
  shot "$dir/$name-before.png"
  w98 motionHold 0 >/dev/null
  w98 app "$during" >/dev/null
  w98 motion "$ev" >/dev/null
  for k in 0 1 2 3 4 5 6 7 8; do
    w98 motionHold "$(hold_ms $k)" >/dev/null; sleep 0.35
    shot "$dir/$name-k$k.png"
    [ "$k" = 4 ] && w98 motionDebug > "$dir/$name-k4.json"
  done
  w98 motionHold -1 >/dev/null; sleep 0.6
  w98 app "$after" >/dev/null; sleep 0.6
  shot "$dir/$name-after.png"
  w98 motionDebug > "$dir/$name-after.json"
}

strip() {  # strip <dir> <name> <png>
  python3 - "$1" "$2" "$3" <<'PY'
import sys
from PIL import Image, ImageDraw
d, name, dst = sys.argv[1:]
cells = ["before"] + ["k%d" % k for k in range(9)] + ["after"]
labels = ["before"] + ["%d ms (frame %d)" % (round(k * 1000 / 60), k) for k in range(9)] + ["after"]
ims = [Image.open("%s/%s-%s.png" % (d, name, c)).convert("RGB") for c in cells]
w = 640
h = round(ims[0].height * w / ims[0].width)
cols, rows = 4, 3
pad, lab = 6, 26
sheet = Image.new("RGB", (cols * (w + pad) + pad, rows * (h + lab + pad) + pad), (16, 16, 16))
dr = ImageDraw.Draw(sheet)
for i, (im, t) in enumerate(zip(ims, labels)):
    x = pad + (i % cols) * (w + pad)
    y = pad + (i // cols) * (h + lab + pad)
    dr.text((x + 4, y + 6), t, fill=(240, 240, 240))
    sheet.paste(im.resize((w, h), Image.LANCZOS), (x, y + lab))
sheet.save(dst)
PY
}

run_theme() {  # run_theme <theme> <mode>
  local theme=$1 mode=$2 work="$out/session-$1-$2" dir="$out/$1-$2"
  mkdir -p "$dir"
  SESSION_THEME=$theme
  export SESSION_THEME
  # shellcheck source=session.sh
  . "$here/session.sh" "$shell_dir" "$work" 2880x1800
  for _ in $(seq 60); do w98 current | grep -q "\"loaded\":\"$theme\"" && break; sleep 0.2; done
  w98 theme "$mode" >/dev/null
  w98 set tb-normal >/dev/null; sleep 1.5
  local win='{"rect":[420,260,900,560],"title":"bar-plan.js - mountainous","active":true}'
  local max='{"rect":[4,35,1912,1116],"title":"bar-plan.js - mountainous","active":true}'
  if [ "$theme" = win98 ]; then
    film minimize '{"kind":"minimize","index":3,"rect":[420,260,900,560]}' "$win" "" "" "$dir"
    film restore '{"kind":"restore","index":3,"rect":[420,260,900,560]}' "" "" "$win" "$dir"
    film maximize '{"kind":"maximize","index":3,"rect":[420,260,900,560],"to":[4,35,1912,1116]}' "$win" "$max" "$max" "$dir"
    film unmaximize '{"kind":"unmaximize","index":3,"rect":[4,35,1912,1116],"to":[420,260,900,560]}' "$max" "$win" "$win" "$dir"
    film close-cut '{"kind":"close","index":3,"rect":[420,260,900,560]}' "$win" "" "" "$dir"
    w98 reduced true >/dev/null
    film minimize-reduced '{"kind":"minimize","index":3,"rect":[420,260,900,560]}' "$win" "" "" "$dir"
    w98 reduced false >/dev/null
  else
    film open '{"kind":"open","index":3,"rect":[420,260,900,560]}' "" "$win" "$win" "$dir"
    film close '{"kind":"close","index":3,"rect":[420,260,900,560]}' "$win" "" "" "$dir"
    film collapse '{"kind":"minimize","index":3,"rect":[420,260,900,560]}' "$win" "" "" "$dir"
    film show '{"kind":"restore","index":3,"rect":[420,260,900,560]}' "" "" "$win" "$dir"
    film zoom-cut '{"kind":"maximize","index":3,"rect":[420,260,900,560],"to":[4,35,1912,1116]}' "$win" "$max" "$max" "$dir"
  fi
  # The page dividers (and the strip's grooves): many pages, and keyboard
  # focus on a window button (Win98).
  w98 app "" >/dev/null
  for st in tb-normal tb-many; do w98 set "$st" >/dev/null; sleep 1.2; shot "$dir/dividers-$st.png"; done
  if [ "$theme" = win98 ]; then w98 set ix-win1-focus >/dev/null; sleep 1.2; shot "$dir/dividers-focus.png"; fi
  cp "$work/qs.log" "$dir/qs.log"
  # No DRM card node was opened by anything in the session.
  for p in $(session_procs); do
    ls -l "/proc/$p/fd" 2>/dev/null | grep -E '/dev/dri/card' && echo "DRM card open by $p" >> "$out/drm.log"
  done
  session_stop
  for f in "$dir"/*-before.png; do
    n=$(basename "$f" -before.png)
    strip "$dir" "$n" "$out/$theme-$mode-$n.filmstrip.png"
  done
}

: > "$out/drm.log"
trap 'type session_stop >/dev/null 2>&1 && session_stop' EXIT
narrow() {  # the Win98 taskbar at 720 x 900 logical, many pages
  local work="$out/session-narrow" dir="$out/win98-narrow"
  mkdir -p "$dir"
  SESSION_THEME=win98; export SESSION_THEME
  # shellcheck source=session.sh
  . "$here/session.sh" "$shell_dir" "$work" 1080x1350
  for _ in $(seq 60); do w98 current | grep -q '"loaded":"win98"' && break; sleep 0.2; done
  for mode in light dark; do
    w98 theme "$mode" >/dev/null
    for st in tb-normal tb-many; do w98 set "$st" >/dev/null; sleep 1.2; shot "$dir/dividers-$st-$mode.png"; done
  done
  w98 places > "$dir/places.json"
  session_stop
}

if [ "${CAPTURE_ONLY:-}" != narrow ]; then
  for theme in win98 platinum; do
    for mode in light dark; do run_theme "$theme" "$mode"; done
  done
fi
narrow
echo "drm: $(wc -l < "$out/drm.log") card opens"
ls "$out"/*.filmstrip.png

#!/usr/bin/env bash
# The Platinum Control Strip's icons in the real shell, at scale 1.5: theme
# art, generated tokens, a build-time token and a letter, raised, pressed in
# and on another page, in light, dark and black (extra dark). Captures the
# strip and measures its pixels against the tile geometry in
# themes/platinum/strip-plan.js (platinum-strip.py): the icon's padding, the
# gap to the ▴, the 1:1 theme art and the stipple.
#
#   platinum-strip.sh <shell dir> <work dir> <out dir> [--no-measure]
#
# Needs the session tools of win98/session.sh (sway, grim, qs), python3 with
# Pillow and numpy, node, the desktop-art package on XDG_DATA_DIRS and as
# DESKTOP_ART, and
# MOUNTAINOUS_PLATINUM_ICON (the token helper, which also generates the
# build-time tokens: mountainous-platinum-app-tokens beside it).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:?work dir}")
out=$(realpath -m "${3:?out dir}")
measure=1
[ "${4:-}" = --no-measure ] && measure=0
mkdir -p "$work/data/applications" "$out"

python3 "$here/platinum-strip-fixtures.py" "$work/data"
# What environment.extraSetup does on a host: tokens for the apps the theme
# has no 32 px art for, as the Mountainous-platinum-apps theme.
tokens=$(dirname "$MOUNTAINOUS_PLATINUM_ICON")/mountainous-platinum-app-tokens
if [ -x "$tokens" ]; then
  "$tokens" "$work/data" "$work/data/icons/Mountainous-platinum-apps" \
    --covered "$DESKTOP_ART/share/icons/Mountainous-platinum"
fi
export XDG_DATA_DIRS="$work/data:$XDG_DATA_DIRS"

export SESSION_THEME=platinum
# shellcheck source=win98/session.sh
. "$here/win98/session.sh" "$shell_dir" "$work" 2880x1800
trap session_stop EXIT
for _ in $(seq 80); do w98 current | grep -q '"loaded":"platinum"' && break; sleep 0.1; done
w98 set strip-icons >/dev/null

for scheme in light dark black; do
  case $scheme in
    light) w98 theme light >/dev/null; w98 extra off >/dev/null ;;
    dark) w98 theme dark >/dev/null; w98 extra off >/dev/null ;;
    black) w98 theme dark >/dev/null; w98 extra on >/dev/null ;;
  esac
  # Tokens arrive from the helper asynchronously; give them time.
  sleep 4
  shot "$work/$scheme-full.png"
done

# A drag (light): the ghost and the drop label at the new tile size. The
# pointer drags Ghostty's tile onto the next one (a swap) and lets go
# where it started. Needs pywayland (pointer.py); skipped without it.
if python3 -c 'import pywayland' 2>/dev/null; then
  w98 theme light >/dev/null; w98 extra off >/dev/null
  mkfifo "$work/pointer"
  python3 "$here/win98/pointer.py" "$work/pointer" 1920 1200 > "$work/pointer.log" 2>&1 &
  session_pids+=($!)
  exec 7>"$work/pointer"
  sleep 1
  # Ghostty is the third tile: CAP + its slot + half a tile; the tiles'
  # middle row, BOTTOM + HEIGHT / 2 above the screen's bottom edge.
  px=$((12 + 86 + 20)); py=$((1200 - 6 - 19))
  echo "move $px $py" >&7; sleep 0.3; echo down >&7; sleep 0.2
  for dx in 10 20 30 42; do echo "move $((px + dx)) $py" >&7; sleep 0.15; done
  sleep 0.8
  shot "$work/drag-full.png"
  for dx in 30 20 10 0; do echo "move $((px + dx)) $py" >&7; sleep 0.15; done
  echo up >&7; sleep 0.5
fi

# Many windows on a narrow screen (600 logical px): the ◂ ▸ arrows show and
# the track scrolls (strip-plan.js plan keeps every tile reachable).
w98 set tb-huge >/dev/null
w98 theme light >/dev/null; w98 extra off >/dev/null
sleep 3
shot "$work/many-wide-full.png"
swaymsg output HEADLESS-1 resolution 900x1800 >/dev/null
sleep 3
shot "$work/many-narrow-full.png"
cp "$work/qs.log" "$out/qs.log"

python3 - "$work" "$out" <<'PY'
import sys
from pathlib import Path
from PIL import Image
work, out = Path(sys.argv[1]), Path(sys.argv[2])
for name in ("light", "dark", "black", "drag", "many-wide", "many-narrow"):
    if not (work / f"{name}-full.png").exists():
        continue
    full = Image.open(work / f"{name}-full.png").convert("RGB")
    strip = full.crop((0, full.height - 150, min(full.width, 1500), full.height))
    strip.save(out / f"strip-{name}.png")
    strip.crop((0, 0, min(strip.width, 600), strip.height)).resize((min(strip.width, 600) * 4, strip.height * 4), Image.NEAREST).save(out / f"strip-{name}-4x.png")
PY

fail=0
if [ "$measure" = 1 ]; then
  # The plan's own answer: strip-plan.js in a VM, as its test loads it.
  node -e '
    const fs = require("node:fs"), vm = require("node:vm");
    const lib = (f) => fs.readFileSync(f, "utf8").replace(/^\.pragma library\s*$/m, "").replace(/^\.import .*$/m, "");
    const P = { PageNames: {} };
    vm.runInNewContext(lib(process.argv[1]), P);
    const rows = [1, 1, 1, 1, 1, 2, 2, 2].map((page, i) => ({ page: page, address: "w" + i }));
    console.log(JSON.stringify({ tile: P.tileGeometry(1.5), slots: P.slots(rows).slots.filter((s) => s.kind === "tile").map((s) => s.x),
      HEIGHT: P.HEIGHT, BOTTOM: P.BOTTOM, TILE_H: P.TILE_H, CAP: P.CAP, RIGHT_EDGE: P.RIGHT_EDGE, MIN_POP_GAP: P.MIN_POP_GAP, desktopArt: process.argv[2] }));
  ' "$shell_dir/themes/platinum/strip-plan.js" "$DESKTOP_ART" > "$work/geometry.json"
  python3 "$here/platinum-strip.py" "$work" "$out" || fail=1
fi
if grep -E 'TypeError|ReferenceError|is not defined|QML.*(Error|Warning)' "$work/qs.log"; then
  echo "FAIL QML warnings (above)"; fail=1
fi
[ "$fail" = 0 ] && echo "PLATINUM_STRIP_PASSED"
exit "$fail"

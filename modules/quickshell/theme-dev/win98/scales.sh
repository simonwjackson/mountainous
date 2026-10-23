#!/usr/bin/env bash
# Two headless outputs at scales 1.5 and 1, a Win98 taskbar on each: every
# taskbar must draw its bevel lines 2 physical px on its own output (each
# window keeps its own unit; Win98Tokens.unitFor).
#
#   modules/quickshell/theme-dev/win98/scales.sh <shell dir> [work dir]
#
# Needs sway, swaymsg, grim, qs and python3 on PATH, FONTCONFIG_FILE with
# W95FA Grid. checks.win98-desktop runs it.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:-$(mktemp -d "${TMPDIR:-/tmp}/win98-scales.XXXXXX")}")
# shellcheck source=session.sh
. "$here/session.sh" "$shell_dir" "$work" 2880x1800
trap session_stop EXIT
swaymsg -q create_output
swaymsg -q output HEADLESS-2 resolution 1920x1200 scale 1 position 1920 0
w98 set tb-normal >/dev/null
fail=0
# The run lengths of one column of the bottom 56 physical px of an output.
column() { grim -o "$1" -t ppm - | python3 -c '
import sys
d = sys.stdin.buffer.read(); parts = d.split(b"\n", 3)
w, h = map(int, parts[1].split()); px = d[len(d) - w * h * 3:]
x = int(sys.argv[1]); runs = []
for y in range(h - 56, h):
    o = (y * w + x) * 3; c = "#%02x%02x%02x" % tuple(px[o:o + 3])
    if runs and runs[-1][0] == c: runs[-1][1] += 1
    else: runs.append([c, 1])
print(" ".join("%d%s" % (n, c) for c, n in runs))' "$2"; }
# Light Windows Standard: li, hi, face, Start's hi and li, face, Start's sh and dk, face.
want="2#dfdfdf 2#ffffff 4#c0c0c0 2#ffffff 2#dfdfdf 36#c0c0c0 2#808080 2#000000 4#c0c0c0"
for out in HEADLESS-1 HEADLESS-2; do
  got=""
  for _ in $(seq 40); do got=$(column "$out" 60); [ "$got" = "$want" ] && break; sleep 0.25; done
  grim -o "$out" "$work/$out.png"
  if [ "$got" = "$want" ]; then echo "PASS $out: bevel lines 2 px ($got)"; else echo "FAIL $out: got '$got', want '$want'"; fail=1; fi
done
if grep -E "WARN scene|TypeError|ReferenceError" "$work/qs.log" >&2; then echo "FAIL QML warnings"; fail=1; fi
[ $fail = 0 ] && echo WIN98_SCALES_PASSED || { echo WIN98_SCALES_FAILED; exit 1; }

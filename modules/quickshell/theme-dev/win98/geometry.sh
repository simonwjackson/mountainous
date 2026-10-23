#!/usr/bin/env bash
# The Win98 Desktop's real control bounds at awkward sizes, from the live
# QML (the harness's geometry IPC), in private headless sway sessions:
#
#   - the taskbar: every control inside the bar, in order, and every window
#     button inside its band, from 1920 down to 40 logical px wide;
#   - Start cascades (Programs > Accessories, Commands > Interface scale)
#     inside the screen and above the bar, at 320 and 160 px wide;
#   - every tray window on a 180 px tall screen: inside the screen and above
#     the bar, scrolling only when it still does not fit;
#   - Display Properties at 160x800, 160x80 and 1200x400: the dialog and
#     OK, Cancel and Apply inside the screen; the focused Apply scrolled
#     into view.
#
#   modules/quickshell/theme-dev/win98/geometry.sh <shell dir> [work dir]
#
# Needs sway, qs, python3 on PATH and FONTCONFIG_FILE with W95FA Grid.
# checks.win98-desktop runs it.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:-$(mktemp -d "${TMPDIR:-/tmp}/win98-geometry.XXXXXX")}")
mkdir -p "$work"
fail=0
pass=0

# check <label> <python expression over g (the geometry), W, H>
check() {
  local out
  out=$(w98 geometry | python3 -c '
import json, sys
g = json.load(sys.stdin); W, H = g["w"], g["h"]; e = 0.51
ins = lambda r, x0=0, y0=0, x1=None, y1=None: r is not None and r["x"] >= x0 - e and r["y"] >= y0 - e \
    and r["x"] + r["w"] <= (W if x1 is None else x1) + e and r["y"] + r["h"] <= (H if y1 is None else y1) + e
insx = lambda r: r["x"] >= -e and r["x"] + r["w"] <= W + e
ok = eval(sys.argv[1])
if not ok: open(sys.argv[2], "w").write(json.dumps(g, indent=1))
print("ok" if ok else "FAIL (geometry in " + sys.argv[2] + ")")' "$2" "$work/fail-$pass-$fail.json" 2>&1) || out="FAIL $out"
  if [ "${out%% *}" = ok ]; then echo "PASS $1"; pass=$((pass + 1)); else echo "FAIL $1: $out"; fail=1; fi
}
settle() { for _ in $(seq 40); do w98 current | grep -q '"settled":true' && break; sleep 0.1; done; sleep 0.6; }
session() {  # session <logical W> <logical H>
  # shellcheck source=session.sh
  . "$here/session.sh" "$shell_dir" "$work/$1x$2" "$(( $1 * 3 / 2 ))x$(( $2 * 3 / 2 ))"
  for _ in $(seq 60); do w98 current | grep -q '"loaded":"win98"' && break; sleep 0.2; done
}

# The bar: every control inside it, in order; window buttons inside their band.
BAR='all(insx(p) for k, p in g["places"].items() if isinstance(p, dict) and "w" in p and k != "tasksArea") \
 and all(p["x"] + p["w"] <= g["places"]["tasksArea"]["x"] + g["places"]["tasksArea"]["w"] + e \
         for k, p in g["places"].items() if k.startswith("win") or k.startswith("page") or k == "tasks") \
 and g["plan"]["fits"] == (W * 0.75 >= 28)'
for size in 1920x1200 600x600 320x600 160x600 80x600 56x600 40x600; do
  w=${size%x*}; h=${size#*x}
  session "$w" "$h"
  for state in tb-normal tb-many dict-failed; do
    w98 set "$state" >/dev/null; settle
    check "taskbar $state at ${size}: inside, in order (structure $(w98 geometry | python3 -c 'import json,sys; print(json.load(sys.stdin)["plan"]["structure"])'))" "$BAR"
  done
  if [ "$w" = 1920 ]; then
    # Room for everything: no panel scrolls or sits scrolled (a panel that
    # scrolled while it opened must show its first row again).
    for state in s-settings s-windows s-commands-scale; do
      w98 set "$state" >/dev/null; settle
      check "Start $state at ${size}: no panel scrolled" \
        'len(g["panels"]) >= 2 and all(not p["scrolls"] and p["scrollY"] == 0 for p in g["panels"])'
    done
  fi
  if [ "$w" = 320 ] || [ "$w" = 160 ]; then
    for state in s-programs s-commands-scale; do
      w98 set "$state" >/dev/null; settle
      check "Start $state at ${size}: every panel on screen, above the bar" \
        'len(g["panels"]) >= 2 and all(ins(p, y1=H - g["places"]["barHeight"] + 3) for p in g["panels"])'
    done
  fi
  session_stop
done

# Start > Programs > Accessories at 320 px, opened by the keyboard path.
session 320 600
w98 set s-top >/dev/null; settle
wtype p 2>/dev/null || true; sleep 0.3; wtype -k Right 2>/dev/null || true; sleep 0.5
check "Start Programs > Accessories at 320x600: every panel on screen" \
  'len(g["panels"]) >= 3 and all(ins(p, y1=H - g["places"]["barHeight"] + 3) for p in g["panels"])'
session_stop

# Every tray window on a short screen. (The Start menu overlaps the bar by
# 2 u, as the mock draws it; the checks allow it.)
session 1200 180
for state in m-bt m-wifi m-sound m-bri m-oci m-disk m-ntf m-builder m-dict-failed m-clock s-logoff s-top; do
  w98 set "$state" >/dev/null; settle
  if [ "$state" = s-top ]; then
    check "Start at 1200x180: inside, above the bar" 'all(ins(p, y1=H - g["places"]["barHeight"] + 3) for p in g["panels"])'
  else
    check "$state at 1200x180: inside the screen; scrolls only when still too tall" \
      'ins(g["window"]) and (g["window"]["scrolls"] == (g["window"]["natural"] > g["window"]["h"] + e))'
  fi
done
session_stop

# Display Properties at small sizes.
for size in 160x800 160x80 1200x400; do
  w=${size%x*}; h=${size#*x}
  session "$w" "$h"
  w98 set pk-win98-light >/dev/null; settle
  check "Display Properties at ${size}: dialog and buttons inside the screen width" \
    'g["picker"] and all(g["picker"][n]["x"] >= -e and g["picker"][n]["x"] + g["picker"][n]["w"] <= W + e for n in ("pickerDialog", "pickerOk", "pickerCancel", "pickerApply", "pickerTheme", "pickerScheme"))'
  # Both tabs inside the dialog, their labels whole and not covered: a
  # narrow sheet wraps its tabs into rows.
  check "Display Properties at ${size}: both tabs inside the dialog, labels whole and uncovered" \
    'g["picker"] and all(g["picker"]["tab%d" % i]["x"] >= g["picker"]["pickerDialog"]["x"] - e and g["picker"]["tab%d" % i]["x"] + g["picker"]["tab%d" % i]["w"] <= g["picker"]["pickerDialog"]["x"] + g["picker"]["pickerDialog"]["w"] + e and g["picker"]["tabLabel%d" % i]["w"] >= 20 for i in (0, 1)) and all(abs(g["picker"]["tab%d" % i]["y"] - g["picker"]["tab%d" % (1 - i)]["y"]) <= 8 or g["picker"]["tab%d" % i]["y"] > g["picker"]["tab%d" % (1 - i)]["y"] or g["picker"]["tabLabel%d" % i]["y"] + g["picker"]["tabLabel%d" % i]["h"] <= g["picker"]["tab%d" % (1 - i)]["y"] + e for i in (0, 1))'
  w98 set pk-apply >/dev/null; settle; sleep 0.4
  check "Display Properties at ${size}: the focused Apply is in view" \
    'g["picker"] and ins(g["picker"]["pickerApply"], y1=g["picker"]["area"])'
  session_stop
done

echo "$pass checks passed"
[ $fail = 0 ] && echo WIN98_GEOMETRY_PASSED || { echo WIN98_GEOMETRY_FAILED; exit 1; }

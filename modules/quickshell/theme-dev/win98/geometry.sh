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
#     into view;
#   - the window and taskbar menus, Shut Down Myoko, System Properties, the
#     Cool Switch and the volume pop-up at 360x640, 800x480, 1280x360 and
#     1920x1200: inside the screen, above the bar, or scrolling;
#   - the Layout window from 360x640 to 1200x180: inside, every control
#     inside its width, and inside its height unless the body scrolls.
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
         for k, p in g["places"].items() if k.startswith("win") or k == "tasks") \
 and not any(k.startswith("page") for k in g["places"]) \
 and all(v["x"] >= g["places"]["tasksArea"]["x"] - e and v["x"] + v["w"] <= g["places"]["tasksArea"]["x"] + g["places"]["tasksArea"]["w"] + e \
         and not any(p["x"] < v["x"] + v["w"] - e and v["x"] < p["x"] + p["w"] - e for k, p in g["places"].items() if k.startswith("win")) \
         for v in g["places"].get("dividers", [])) \
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

# The taskbar and session pieces, from 360x640 up (nothing may become
# unreachable): the window menu with its Move to cascade open and the
# taskbar menu inside the screen, above the bar; Shut Down Myoko with its
# choices, OK and Cancel inside the screen (or its body scrolls with the
# caption kept); System Properties with OK inside, or scrolling; the Cool
# Switch box and the pop-up inside the room above the bar.
ROOM='y1=H - g["places"]["barHeight"] + e'
for size in 360x640 800x480 1280x360 1920x1200; do
  w=${size%x*}; h=${size#*x}
  session "$w" "$h"
  for state in tb-normal tb-many; do
    w98 set "$state" >/dev/null; settle
    w98 windowMenu 1001 $(( w - 10 )) $(( h - 60 )) >/dev/null; sleep 0.5; w98 cascade 1 >/dev/null; sleep 0.5
    check "window menu and Move to at ${size} ($state): every panel inside, above the bar" \
      "len(g['panels']) == 2 and all(ins(p, $ROOM) for p in g['panels'])"
    w98 closeAll >/dev/null; sleep 0.2
    w98 taskbarMenu $(( w - 4 )) >/dev/null; sleep 0.5
    check "taskbar menu at ${size} ($state): inside, above the bar" "len(g['panels']) == 1 and all(ins(p, $ROOM) for p in g['panels'])"
    w98 closeAll >/dev/null; sleep 0.2
  done
  w98 set tb-many >/dev/null; settle
  w98 openMenu shutdown >/dev/null; sleep 0.8
  check "Shut Down Myoko at ${size}: the dialog inside; OK, Cancel and the choices inside or the body scrolls" \
    'g.get("shutdown") and ins(g["shutdown"]) and (g["shutdown"]["scrolls"] or all(g["shutdown"][n] and ins(g["shutdown"][n]) for n in ("shutDownOk", "shutDownCancel", "shutDown-standby", "shutDown-logoff")))'
  w98 closeAll >/dev/null; sleep 0.2
  w98 openMenu sysprops >/dev/null; sleep 0.8
  check "System Properties at ${size}: inside above the bar; OK inside or the body scrolls" \
    "g['window'] and ins(g['window'], $ROOM) and (g['window']['scrolls'] or ins(g['window'].get('systemOk'), $ROOM))"
  w98 closeAll >/dev/null; sleep 0.2
  w98 cycle step 2 $(( $(date +%s%N) / 1000000 )) >/dev/null; sleep 0.6
  check "Cool Switch at ${size} (12 windows): inside, above the bar" "g.get('cool') and ins(g['cool'], $ROOM)"
  w98 cycle cancel 0 $(( $(date +%s%N) / 1000000 )) >/dev/null; sleep 0.3
  sleep 2.2; w98 setVolume $(( 30 + w % 50 )) >/dev/null; sleep 0.4
  check "volume pop-up at ${size}: inside, above the bar" "g.get('popup') and ins(g['popup'], $ROOM)"
  session_stop
done

# The Layout window from 360x640 down to a 180-px-tall strip: inside the
# room above the bar; every control inside the window's width, and inside
# its height unless the body scrolls (then the keys and the scroll bar
# reach it). Each control by objectName (w98 at menu rect:<name>).
layout_controls() {  # layout_controls <label> <names...>
  local label=$1 out n rects="{"; shift
  for n in "$@"; do rects="$rects\"$n\": $(w98 at menu "rect:$n" | grep . || echo null),"; done
  rects="${rects%,}}"
  out=$(python3 -c '
import json, sys
g = json.loads(sys.argv[1]); w = g["window"]; e = 0.51
bad = []
for n, r in json.loads(sys.argv[2]).items():
    if r is None: bad.append(n + " missing"); continue
    if r["x"] < w["x"] - e or r["x"] + r["w"] > w["x"] + w["w"] + e: bad.append(n + " outside the width")
    if not w["scrolls"] and (r["y"] < w["y"] - e or r["y"] + r["h"] > w["y"] + w["h"] + e): bad.append(n + " outside the height")
print("ok" if not bad else "FAIL " + ", ".join(bad))' "$(w98 geometry)" "$rects")
  if [ "$out" = ok ]; then echo "PASS $label"; pass=$((pass + 1)); else echo "FAIL $label: $out"; fail=1; fi
}
for size in 360x640 800x480 1280x360 1200x180 1920x1200; do
  w=${size%x*}; h=${size#*x}
  session "$w" "$h"
  for state in m-layout m-layout-gap m-layout-floating m-layout-default; do
    w98 set "$state" >/dev/null; settle
    check "Layout $state at ${size}: inside, above the bar; scrolls only when still too tall" \
      "g['window'] and ins(g['window'], $ROOM) and (g['window']['scrolls'] == (g['window']['natural'] > g['window']['h'] + e))"
    case $state in
      m-layout-default) layout_controls "Layout $state at ${size}: every control reachable" layoutTiled layoutFloating layoutCap1 layoutCap2 layoutCap3 layoutGap layoutResetAll ;;
      m-layout-gap) layout_controls "Layout $state at ${size}: every control reachable" layoutTiled layoutFloating layoutCap1 layoutCap3 layoutGap layoutCapDefault layoutGapDefault layoutZen ;;
      *) layout_controls "Layout $state at ${size}: every control reachable" layoutTiled layoutFloating layoutCap1 layoutCap2 layoutCap3 layoutGap layoutZen ;;
    esac
  done
  session_stop
done

echo "$pass checks passed"
[ $fail = 0 ] && echo WIN98_GEOMETRY_PASSED || { echo WIN98_GEOMETRY_FAILED; exit 1; }

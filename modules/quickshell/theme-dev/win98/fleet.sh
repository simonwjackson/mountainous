#!/usr/bin/env bash
# The Win98 Fleet window and glance space against the real QML, in private
# headless sway sessions (session.sh), with a virtual pointer and keyboard:
#
#   behaviour  Super+B (the fleet IPC's toggleFleet), the tray Fleet icon
#              (click, right-click menu), a row opens Properties, its tabs,
#              Esc closes the sheet then the window, Minimize and restore
#              from the taskbar, View > Large Icons, a column header sorts,
#              Super+W (toggleGlance) summons the space with the caption
#              animation (frame 9 by 200 ms), the Glance button's menu and
#              its accessory checks, a double-click on it hides the space,
#              Esc, a background click and a taskbar window button dismiss
#              it, reduced motion cuts;
#   geometry   at 360x640, 800x480, 1280x800, 1920x1200 and 2560x1600 at
#              1.5 (the tablet at 2): the window, the sheet and every
#              accessory inside the work area; Fleet in one place in both
#              hosts while the space does not scroll; no accessory overlaps
#              another at rest; the sheet's tabs inside the sheet.
#
# checks.win98-desktop runs it; by hand:
#
#   modules/quickshell/theme-dev/win98/fleet.sh <shell dir> [work dir]
#
# Needs sway, wtype, qs and a python3 with pywayland on PATH, WLR_PROTOCOL
# and WAYLAND_XML for pointer.py, and FONTCONFIG_FILE with W95FA Grid.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:-$(mktemp -d "${TMPDIR:-/tmp}/win98-fleet.XXXXXX")}")
mkdir -p "$work"
fail=0
pass=0
ok() { echo "PASS $1"; pass=$((pass + 1)); }
bad() { echo "FAIL $1"; fail=1; }

# py <expression over f (w98 fleet), W, H>: prints True or False.
py() { w98 fleet | python3 -c '
import json, sys
f = json.load(sys.stdin); v = f["views"] or {}; win = v.get("window") or {}; gl = v.get("glance") or {}; e = 0.51
ins = lambda r, x0, y0, x1, y1: r is not None and r["x"] >= x0 - e and r["y"] >= y0 - e and r["x"] + r["w"] <= x1 + e and r["y"] + r["h"] <= y1 + e
over = lambda a, b: a["x"] < b["x"] + b["w"] - e and b["x"] < a["x"] + a["w"] - e and a["y"] < b["y"] + b["h"] - e and b["y"] < a["y"] + a["h"] - e
print(bool(eval(sys.argv[1])))' "$1" 2>&1; }
check() {   # check <label> <expression>
  local got
  for _ in $(seq 30); do got=$(py "$2"); [ "$got" = True ] && break; sleep 0.1; done
  if [ "$got" = True ]; then ok "$1"; else bad "$1 ($got)"; w98 fleet > "$work/fail-$pass-$fail.json"; fi
}

start_pointer() {   # start_pointer <logical W> <logical H>
  rm -f "$work/pointer.fifo"
  mkfifo "$work/pointer.fifo"
  python3 "$here/pointer.py" "$work/pointer.fifo" "$1" "$2" > "$work/pointer.log" 2>&1 &
  session_pids+=($!)
  exec 3>"$work/pointer.fifo"
  for _ in $(seq 50); do grep -q ready "$work/pointer.log" && break; sleep 0.1; done
  grep -q ready "$work/pointer.log" || { cat "$work/pointer.log" >&2; echo "no virtual pointer" >&2; exit 1; }
}
at() { [ $# -ge 2 ] || { echo "(no such control)"; return 0; }; echo "move $1 $2" >&3; sleep 0.25; }
click_at() { [ $# -ge 2 ] || { echo "(no such control)"; return 0; }; at "$1" "$2"; echo down >&3; sleep 0.05; echo up >&3; sleep 0.4; }
right_at() { [ $# -ge 2 ] || { echo "(no such control)"; return 0; }; at "$1" "$2"; echo right >&3; sleep 0.4; }
key() { wtype -k "$1"; sleep 0.3; }
# The centre of a taskbar control, in logical px.
bar_centre() {
  for _ in $(seq 30); do w98 places | grep -q "\"$1\"" && break; sleep 0.1; done
  w98 places | python3 -c 'import json,sys; d=json.load(sys.stdin); p=d[sys.argv[1]]; print(round(p["x"]+p["w"]/2), round(float(sys.argv[2]) - d["barHeight"]/2))' "$1" "$H"
}
item() {   # item <window|glance|menu> <name>
  local r=""
  for _ in $(seq 30); do r=$(w98 fleetItem "$1" "$2"); [ -n "$r" ] && break; sleep 0.1; done
  echo "$r"
}
session() {   # session <logical W> <logical H> [scale]
  W=$1; H=$2
  local scale=${3:-1.5}
  # shellcheck source=session.sh
  SESSION_SCALE=$scale . "$here/session.sh" "$shell_dir" "$work/$1x$2" "$(python3 -c "print(round($1 * $scale), end='x'); print(round($2 * $scale))")"
  for _ in $(seq 60); do w98 current | grep -q '"loaded":"win98"' && break; sleep 0.2; done
  w98 set tb-normal >/dev/null
  for _ in $(seq 100); do w98 places | grep -q '"fleet"' && break; sleep 0.2; done
  sleep 1
}

# ---------------------------------------------------------------- behaviour
session 1920 1200
start_pointer 1920 1200
trap 'echo quit >&3 2>/dev/null; session_stop' EXIT

check 'the tray shows the Fleet icon' '"fleet" in f["plan"]["tray"] and f["state"] == "ready"'
check 'the Fleet icon polls Beszel while the taskbar shows' 'f["shown"] and not f["detailShown"]'
check 'unzen-problem: danger, one problem' 'f["tone"] == "danger" and f["problems"] == ["unzen"]'
at $(bar_centre fleet); sleep 0.9
check 'the Fleet icon tooltip names the problem' '"unzen" in f["tooltip"] and f["tooltip"].startswith("Fleet:")'
w98 fleetCall toggleFleet >/dev/null
check 'Super+B opens the Fleet window' 'win.get("visible") and f["detailShown"]'
check 'the window stands above the tray at the bottom right' \
  'abs(win["frame"]["x"] + win["frame"]["w"] - (1920 - 6 * win["u"])) < 1 and abs(win["frame"]["y"] + win["frame"]["h"] - (win["height"] - 4 * win["u"])) < 1'
# (That it opens without the keyboard is Hyprland's on-demand focus; sway
# focuses an on-demand layer surface when it maps, so it is not checked here.)
check 'Details at level 0 with the Platinum columns' 'win["level"] == 0 and win["cols"] == ["cpu", "mem", "disk", "temp", "failed", "up"]'
w98 fleetCall toggleFleet >/dev/null
check 'Super+B again closes it' 'not win.get("visible")'
click_at $(bar_centre fleet)
check 'a click on the Fleet icon opens it' 'win.get("visible")'
click_at $(item window row-unzen)
check 'a click on unzen selects it and opens its Properties' 'f["selected"] == "unzen" and f["expanded"] == "unzen" and win["sheet"] is not None'
check 'the sheet stands beside Fleet on the left, bottom-aligned' \
  'win["sheetBeside"] and win["sheet"]["x"] + win["sheet"]["w"] <= win["frame"]["x"] and abs(win["sheet"]["y"] + win["sheet"]["h"] - win["frame"]["y"] - win["frame"]["h"]) < 1'
check 'the click gave the window the keyboard' 'win["focused"]'
check 'Beszel fetched the open host only' 'f["details"] == ["unzen"]'
click_at $(item window tab2)
check 'the Services tab' 'v["tab"] == 2'
wtype -M ctrl -k Tab -m ctrl; sleep 0.3
check 'Ctrl+Tab: the Disks tab' 'v["tab"] == 3'
key Escape
check 'the first Esc closes only the sheet' 'f["expanded"] == "" and win["visible"]'
key Down
check 'Down moves the selection' 'f["selected"] != "unzen"'
key Escape
check 'the second Esc closes the window' 'not win.get("visible")'
w98 fleetCall toggleFleet >/dev/null; sleep 0.5
click_at $(item window captionMinimize)
check 'Minimize puts Fleet on the taskbar' 'v["minimized"] and not win["visible"] and "fleet" in f["plan"]["extras"]'
check 'a minimized window still polls' 'f["detailShown"]'
click_at $(bar_centre fleetbutton)
check 'its taskbar button restores it' 'not v["minimized"] and win["visible"]'
click_at $(item window menu-view)
check 'the View menu opens from the menu bar' 'win["menu"] == "view"'
click_at $(item window "menu:Large Icons")
check 'View > Large Icons' 'v["view"] == "icons" and win["menu"] == ""'
click_at $(item window menu-view); click_at $(item window "menu:Details")
check 'View > Details' 'v["view"] == "details"'
click_at $(item window head-disk)
check 'a click on the Disk header sorts by disk' 'f["sort"] == "disk"'
click_at $(item window head-disk)
check 'a second click goes back to name order' 'f["sort"] == "name"'
right_at $(bar_centre fleet)
check 'a right click on the Fleet icon opens its menu' 'f["open"] == "fleetmenu"'
key Escape; sleep 0.2
w98 fleetCall toggleFleet >/dev/null
check 'closed again' 'not win["visible"]'

# The glance space.
w98 fleetCall toggleGlance >/dev/null
check 'Super+W summons the space' 'gl["phase"] == "shown" and gl["widgets"]'
check 'the Glance button stands on the taskbar' '"glance" in f["plan"]["extras"]'
check 'Fleet and Disks from the bottom right, Fleet first' 'gl["ids"] == ["fleet", "disks"] and gl["rects"]["fleet"]["y"] > gl["rects"]["disks"]["y"]'
click_at $(bar_centre glance)
check 'a click on the Glance button opens the Glance menu' 'f["open"] == "glance"'
click_at $(item menu Disks)
check 'its Disks check turns Disks off' 'f["enabled"]["disks"] == False and gl["ids"] == ["fleet"]'
click_at $(bar_centre glance); click_at $(item menu Disks)
check 'and on again' 'f["enabled"]["disks"] == True and gl["ids"] == ["fleet", "disks"]'
click_at $(item glance row-tate)
check 'a row in the glance Fleet opens Properties over the space' 'gl["sheet"] is not None and f["expanded"] == "tate"'
key Escape
check 'Esc closes the sheet first' 'gl["sheet"] is None and gl["phase"] == "shown"'
key Escape
check 'a second Esc dismisses the space' 'gl["phase"] == "hidden" and not gl["visible"]'
w98 fleetCall toggleGlance >/dev/null; sleep 0.6
click_at 300 300
check 'a background click dismisses it' 'gl["phase"] == "hidden"'
w98 fleetCall toggleGlance >/dev/null; sleep 0.6
gb=$(bar_centre glance)
at $gb; echo down >&3; sleep 0.03; echo up >&3; sleep 0.08; echo down >&3; sleep 0.03; echo up >&3; sleep 0.5
check 'a double-click on the Glance button hides the space' 'gl["phase"] == "hidden" and f["open"] == ""'
w98 fleetCall toggleGlance >/dev/null; sleep 0.6
click_at $(bar_centre win1)
check 'a taskbar window button dismisses the space' 'gl["phase"] == "hidden"'
grep -q "activate 1" "$work/1920x1200/commands.log" 2>/dev/null || w98 commands | grep -q "activate 1" && ok 'and switches to its window' || bad 'the window button did not switch'
w98 fleetCall toggleFleet >/dev/null; sleep 0.4; w98 fleetCall toggleGlance >/dev/null; sleep 0.6
check 'the standalone window stays under the space' 'win["visible"] and gl["phase"] == "shown"'
w98 fleetCall toggleFleet >/dev/null; sleep 0.6
check 'Super+B from the space goes back to the window' 'gl["phase"] == "hidden" and win["visible"]'
w98 fleetCall toggleFleet >/dev/null

# Motion: the trace of a summon, then reduced motion.
w98 fleetSet reduced false >/dev/null
w98 fleetCall toggleGlance >/dev/null; sleep 0.6; w98 fleetCall toggleGlance >/dev/null; sleep 0.6
w98 seek 50 in >/dev/null
check 'a held frame 3 draws the captions in flight, no windows' 'gl["k"] == 3 and gl["caption"] is not None and 0 < gl["caption"] < 1 and not gl["widgets"] and gl["background"]'
w98 seek 151 in >/dev/null
check 'frame 9 (151 ms): the windows, no caption' 'gl["k"] == 9 and gl["caption"] is None and gl["widgets"]'
w98 seek 50 out >/dev/null
check 'the dismiss is the mirror: captions, the dither still on' 'gl["caption"] is not None and gl["background"] and not gl["widgets"]'
w98 seek -1 in >/dev/null; sleep 0.3
w98 fleetSet reduced true >/dev/null
w98 fleetCall toggleGlance >/dev/null; sleep 0.2
check 'reduced motion: the cut' 'gl["phase"] == "shown" and gl["caption"] is None'
w98 fleetCall toggleGlance >/dev/null; sleep 0.2
w98 fleetSet reduced false >/dev/null

# Every fixture: the window and the space draw it.
for fx in live healthy unzen-problem vm-no-sensor desktop-down server-down rakku-down error loading stale stress empty; do
  w98 fleetFixture "$fx" >/dev/null; sleep 1.2
  [ "$fx" = stale ] && sleep 1
  case "$fx" in
    rakku-down) want='f["state"] == "unavailable"' ;;
    error) want='f["state"] == "error"' ;;
    loading) want='f["state"] == "loading"' ;;
    stale) want='f["stale"]' ;;
    empty) want='f["state"] == "ready" and f["hosts"] == 0' ;;
    *) want='f["state"] == "ready" and f["hosts"] > 0' ;;
  esac
  check "fixture $fx reaches its state" "$want"
done
w98 fleetFixture unzen-problem >/dev/null; sleep 1

if grep -E "WARN scene|QQmlVMEMetaObject|TypeError|ReferenceError" "$work/1920x1200/qs.log" >&2; then bad "QML warnings in the behaviour run"; else ok "no QML warnings in the behaviour run"; fi
echo quit >&3 2>/dev/null || true
session_stop
trap - EXIT

# ---------------------------------------------------------------- geometry
# The work area: the screen less the taskbar's zone (ceil 28 u).
AREA='(lambda wa: {"x": 0, "y": 0, "w": f["taskbar"]["width"], "h": wa})(gl["spaceH"] if gl else 0)'
for spec in 360x640:1.5 800x480:1.5 1280x800:1.5 1920x1200:1.5 1280x800:2; do
  size=${spec%:*}; scale=${spec#*:}
  w=${size%x*}; h=${size#*x}
  session "$w" "$h" "$scale"
  label="${size}@${scale}"
  for fx in unzen-problem stress; do
    w98 fleetFixture "$fx" >/dev/null; sleep 1.2
    w98 fleetSet expanded "" >/dev/null
    w98 fleetCall toggleFleet >/dev/null; sleep 0.8
    check "$label $fx: the window inside the work area" 'ins(win["frame"], 0, 0, win["width"], win["height"])'
    fr=$(w98 fleet | python3 -c 'import json,sys; f=json.load(sys.stdin); print(json.dumps(f["views"]["window"]["frame"]))')
    w98 fleetSet expanded unzen >/dev/null; sleep 0.8
    check "$label $fx: the sheet inside the work area" 'win["sheet"] is not None and ins(win["sheet"], 0, 0, win["width"], win["height"])'
    w98 fleetSet expanded "" >/dev/null
    w98 fleetCall toggleFleet >/dev/null; sleep 0.3
    w98 fleetCall toggleGlance >/dev/null; sleep 0.8
    check "$label $fx: every accessory inside the space (across)" 'all(r["x"] >= -e and r["x"] + r["w"] <= gl["wU"] * gl["u"] + e for r in gl["rects"].values())'
    check "$label $fx: no accessory overlaps another at rest" \
      'all(not over(a, b) for i, a in enumerate(gl["rects"].values()) for j, b in enumerate(gl["rects"].values()) if i < j)'
    check "$label $fx: Fleet in the window's place while the space does not scroll" \
      "gl['scroll'] or (lambda a, b: abs(a['x'] - b['x']) < 1 and abs(a['y'] - b['y']) < 1 and abs(a['w'] - b['w']) < 1)(gl['rects']['fleet'], $fr)"
    check "$label $fx: a scrolled space starts at Fleet (the bottom)" \
      'not gl["scroll"] or abs(gl["contentY"] - (gl["contentH"] - gl["viewH"])) < 1'
    w98 fleetSet expanded unzen >/dev/null; sleep 0.8
    check "$label $fx: the glance sheet inside the space" 'gl["sheet"] is not None and ins(gl["sheet"], 0, 0, gl["wU"] * gl["u"], gl["spaceH"])'
    w98 fleetSet expanded "" >/dev/null
    w98 fleetCall toggleGlance >/dev/null; sleep 0.5
  done
  check "$label: the taskbar plan still fits with the Fleet icon" 'f["plan"]["fits"]'
  if grep -E "WARN scene|QQmlVMEMetaObject|TypeError|ReferenceError" "$work/$w"x"$h/qs.log" >&2; then bad "$label: QML warnings"; else ok "$label: no QML warnings"; fi
  session_stop
done

echo "$pass checks passed"
[ $fail = 0 ] && echo WIN98_FLEET_PASSED || { echo WIN98_FLEET_FAILED; exit 1; }

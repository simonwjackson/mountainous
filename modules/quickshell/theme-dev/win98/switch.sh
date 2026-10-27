#!/usr/bin/env bash
# Platinum <-> Win98, ten round trips each way, through the real
# ThemeDesktop and theme-name file, then a broken Win98 that must roll
# back. Before every swap a transient surface is open: a Start cascade, a
# tray window or menu, or the picker, and under Win98 also the window menu,
# the taskbar menu, Shut Down Myoko, System Properties, the Cool Switch
# and the volume pop-up (rotating), over the theme's Fleet window or glance
# space (alternating). After each swap it asserts:
#
# Part 1, a private headless sway session (sway reports the usable area):
#   - the reserved edge: the workspace rectangle starts 28 px down for
#     Platinum (its top bar) and ends 38 px up for Win98 (its taskbar);
#   - no chrome of the old theme on screen (screenshot pixels);
#   - one loaded Desktop slot and no QML warning.
#
# Part 2, a niri nested in a headless sway (software GL), because niri
# lists its mapped layer-shell surfaces (niri msg layers) and sway does
# not: the exact set of mapped layer surfaces after each swap: the new
# theme's bars, plus the picker when it was open (the picker model is
# shared across a swap by contract), and nothing else: no leaked menu,
# cascade, tooltip, old bar, Fleet window (mountainous-fleet) or glance
# space (mountainous-glance), Shut Down checker (mountainous-shutdown), Cool
# Switch (mountainous-coolswitch) or pop-up (mountainous-popup). Before
# every swap the old theme's Fleet window
# or glance space is open and mapped. The same after the broken Win98's
# rollback.
#
# checks.win98-desktop runs it; by hand:
#
#   modules/quickshell/theme-dev/win98/switch.sh <shell dir> [work dir]
#
# Needs sway, swaymsg, grim, niri, qs, python3 on PATH and FONTCONFIG_FILE
# with W95FA Grid.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:-$(mktemp -d "${TMPDIR:-/tmp}/win98-switch.XXXXXX")}")
fail=0
pass=0

name() { printf '%s\n' "$1" > "$XDG_STATE_HOME/mountainous/theme-name.new"; mv "$XDG_STATE_HOME/mountainous/theme-name.new" "$XDG_STATE_HOME/mountainous/theme-name"; }
loaded() { w98 current | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["loaded"], d["slots"])'; }
wait_loaded() { for _ in $(seq 80); do [ "$(loaded)" = "$1 1" ] && return 0; sleep 0.1; done; return 1; }
ok() { echo "PASS $1"; pass=$((pass + 1)); }
bad() { echo "FAIL $1"; fail=1; }
expect() { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1: got '$2', want '$3'"; fi; }
settle() { for _ in $(seq 40); do w98 current | grep -q '"settled":true' && break; sleep 0.1; done; sleep 0.5; }

# The Fleet view open before a swap, by round: the Fleet window on even
# rounds, the glance space on odd ones (each theme's own, through the
# Desktop methods the fleet and glance IPC call). Neither may survive the
# swap: the old Desktop's views go with it, and GlanceState forgets them.
open_fleet() {   # open_fleet <round>
  if [ $(( $1 % 2 )) = 0 ]; then w98 fleetCall toggleFleet >/dev/null; echo fleet; else w98 fleetCall toggleGlance >/dev/null; echo glance; fi
  sleep 0.6
}

# The transient surface open before a swap, by round. Win98 uses the
# harness states, then (rounds 3 to 9) a window button's window menu, the
# taskbar's own menu, Shut Down Myoko over its checker, System Properties,
# the Cool Switch (held Super+Tab) and the volume pop-up; Platinum is
# opened through the shared MenuState and ThemePicker. Prints what is
# open ("picker" when the picker is the one left open).
cycle_seq=$(( $(date +%s) % 100000 * 100 ))
open_transient() {   # open_transient <theme> <round>
  local kinds=3
  [ "$1" = win98 ] && kinds=9
  case "$1:$(( $2 % kinds ))" in
    win98:0) w98 set s-programs-internet >/dev/null; settle; echo cascade ;;
    win98:1) w98 set m-sound >/dev/null; settle; echo window ;;
    win98:2) w98 set pk-win98-light >/dev/null; settle; echo picker ;;
    win98:3) w98 windowMenu 1001 600 700 >/dev/null; sleep 0.6; echo winmenu ;;
    win98:4) w98 taskbarMenu 900 >/dev/null; sleep 0.6; echo tbmenu ;;
    win98:5) w98 openMenu shutdown >/dev/null; sleep 0.8; echo shutdown ;;
    win98:6) w98 openMenu sysprops >/dev/null; sleep 0.8; echo sysprops ;;
    win98:7) cycle_seq=$((cycle_seq + 1)); w98 cycle step 2 "$cycle_seq" >/dev/null; sleep 0.6; echo cool ;;
    win98:8) for _ in $(seq 50); do w98 popup | grep -q '"armed":\[true' && break; sleep 0.1; done
             w98 setVolume $(( 20 + $2 )) >/dev/null; sleep 0.3; echo popup ;;
    platinum:0) w98 openMenu vol >/dev/null; sleep 0.6; echo menu ;;
    platinum:1) w98 openMenu clock >/dev/null; sleep 0.6; echo menu ;;
    platinum:2) w98 openPicker >/dev/null; sleep 0.8; echo picker ;;
  esac
}
# The layer surface a transient maps.
surface_of() {
  case "$1" in
    picker) echo mountainous-picker ;; shutdown) echo mountainous-shutdown ;;
    cool) echo mountainous-coolswitch ;; popup) echo mountainous-popup ;; *) echo mountainous-menu ;;
  esac
}

# ---------------------------------------------------------------- part 1
# shellcheck source=session.sh
. "$here/session.sh" "$shell_dir" "$work/run1" 2880x1800
trap session_stop EXIT
swaymsg -q output HEADLESS-1 bg '#204060' solid_color
sleep 1
rect() { swaymsg -t get_workspaces | python3 -c 'import json,sys; w=[w for w in json.load(sys.stdin) if w["focused"]][0]["rect"]; print(w["y"], w["height"])'; }
# The colour of physical pixel (x, y) of the output.
pixel() { grim -t ppm - | python3 -c '
import sys
d = sys.stdin.buffer.read()
parts = d.split(b"\n", 3)
w, h = map(int, parts[1].split())
x, y = int(sys.argv[1]), int(sys.argv[2])
o = len(d) - w * h * 3 + (y * w + x) * 3
print("#%02x%02x%02x" % tuple(d[o:o + 3]))' "$1" "$2"; }
assert_zone() {
  local t=$1 round=$2
  wait_loaded "$t" || bad "round $round: $t did not load ($(loaded))"
  # The first map of a theme compiles it; give the zone up to 4 s.
  for _ in $(seq 40); do
    read -r y height < <(rect)
    if [ "$t" = win98 ]; then [ "$y $height" = "0 1162" ] && break; else [ "$y" = 28 ] && break; fi
    sleep 0.1
  done
  sleep 0.3
  if [ "$t" = win98 ]; then
    expect "round $round win98: usable area starts at the top" "$y" 0
    expect "round $round win98: the taskbar reserves 38 px at the bottom" "$height" 1162
    expect "round $round win98: no top bar on screen" "$(pixel 1440 10)" "#204060"
    expect "round $round win98: the taskbar on screen" "$(pixel 1 1797)" "#c0c0c0"
  else
    expect "round $round platinum: the top bar reserves 28 px" "$y" 28
    expect "round $round platinum: no taskbar on screen" "$(pixel 1 1797)" "#204060"
  fi
}

w98 set tb-normal >/dev/null
name platinum
assert_zone platinum 0
for round in 1 2 3 4 5 6 7 8 9 10; do
  f=$(open_fleet "$round")
  echo "round $round: from platinum with its $f and a $(open_transient platinum "$round") open"
  name win98
  assert_zone win98 "$round"
  expect "round $round win98: no Fleet view carried over" "$(w98 fleet | python3 -c 'import json,sys; f=json.load(sys.stdin); print(f["glanceScreen"] + "|" + f["fleetScreen"])')" "|"
  w98 closeAll >/dev/null
  f=$(open_fleet "$round")
  echo "round $round: from win98 with its $f and a $(open_transient win98 "$round") open"
  name platinum
  assert_zone platinum "$round"
  expect "round $round platinum: no Fleet view carried over" "$(w98 fleet | python3 -c 'import json,sys; f=json.load(sys.stdin); print(f["glanceScreen"] + "|" + f["fleetScreen"])')" "|"
  w98 closeAll >/dev/null
done
if grep -E "WARN scene|QQmlVMEMetaObject|TypeError|ReferenceError|Failed to load" "$work/run1/qs.log" >&2; then bad "QML warnings in 20 switches"; else ok "no QML warnings in 20 switches"; fi
grep -q "Desktop theme could not load" "$work/run1/commands.log" 2>/dev/null && bad "a notification during good switches" || ok "no failure notification"
session_stop

# ---------------------------------------------------------------- part 2
layers() { niri msg --json layers | python3 -c 'import json,sys; print(" ".join(sorted(l["namespace"] for l in json.load(sys.stdin))))'; }
# What must be mapped after a swap: the theme's bars, plus the picker.
want_layers() {   # want_layers <theme> <picker:0|1>
  if [ "$1" = win98 ]; then
    [ "$2" = 1 ] && echo "mountainous-picker mountainous-taskbar" || echo "mountainous-taskbar"
  else
    # Platinum: its top bar, the bar's shadow and its dock, plus its picker view.
    [ "$2" = 1 ] && echo "mountainous-bar-shadow quickshell quickshell quickshell" || echo "mountainous-bar-shadow quickshell quickshell"
  fi
}
assert_layers() {   # assert_layers <label> <theme> <picker>
  local want got
  want=$(want_layers "$2" "$3")
  for _ in $(seq 30); do got=$(layers); [ "$got" = "$want" ] && break; sleep 0.1; done
  expect "$1: mapped layer surfaces" "$got" "$want"
}
export SESSION_COMPOSITOR=niri
. "$here/session.sh" "$shell_dir" "$work/run2" 2880x1800
w98 set tb-normal >/dev/null
name platinum
wait_loaded platinum || bad "platinum did not load under niri"
assert_layers "niri start platinum" platinum 0
for round in 1 2 3 4 5 6 7 8 9 10; do
  f=$(open_fleet "$round")
  [[ " $(layers) " == *" mountainous-$f "* ]] && ok "niri round $round: Platinum's $f is mapped before the swap" || bad "niri round $round: no Platinum $f before the swap ($(layers))"
  what=$(open_transient platinum "$round")
  [ "$what" = picker ] && p=1 || p=0
  name win98
  wait_loaded win98 || bad "niri round $round: win98 did not load"
  assert_layers "niri round $round platinum -> win98 (a $what was open)" win98 "$p"
  w98 closeAll >/dev/null; sleep 0.3
  f=$(open_fleet "$round")
  [[ " $(layers) " == *" mountainous-$f "* ]] && ok "niri round $round: Win98's $f is mapped before the swap" || bad "niri round $round: no Win98 $f before the swap ($(layers))"
  what=$(open_transient win98 "$round")
  [ "$what" = picker ] && p=1 || p=0
  # The transient is really mapped before the swap.
  ns=$(surface_of "$what")
  [[ " $(layers) " == *" $ns "* ]] && ok "niri round $round: the $what ($ns) is mapped before the swap" || bad "niri round $round: no $what before the swap ($(layers))"
  name platinum
  wait_loaded platinum || bad "niri round $round: platinum did not load"
  assert_layers "niri round $round win98 -> platinum (a $what was open)" platinum "$p"
  w98 closeAll >/dev/null; sleep 0.3
done
if grep -E "WARN scene|QQmlVMEMetaObject|TypeError|ReferenceError|Failed to load" "$work/run2/qs.log" >&2; then bad "QML warnings under niri"; else ok "no QML warnings under niri"; fi
session_stop

# ---------------------------------------------------------------- broken
# A broken Win98 (a type that does not exist) must leave Platinum in place,
# its zone and its surfaces, write platinum back to theme-name and send
# one notification.
broken="$work/broken-shell"
rm -rf "$broken"; cp -r "$shell_dir" "$broken"; chmod -R u+w "$broken"
sed 's/^Scope {$/ThisWin98IsDeliberatelyBroken {/' "$broken/Win98Desktop.qml" > "$broken/Win98Broken.qml"
python3 - "$broken/themes.json" <<'EOF'
import json, sys
p = sys.argv[1]; t = json.load(open(p))
for e in t:
    if e["id"] == "win98": e["desktop"] = "Win98Broken.qml"
json.dump(t, open(p, "w"))
EOF
SESSION_THEME=platinum . "$here/session.sh" "$broken" "$work/run3" 2880x1800
name platinum
wait_loaded platinum || bad "broken: platinum did not load"
assert_layers "broken: before" platinum 0
w98 openMenu vol >/dev/null; sleep 0.5
name win98
for _ in $(seq 60); do grep -q "Desktop theme could not load" "$work/run3/commands.log" 2>/dev/null && break; sleep 0.1; done
sleep 0.5
if grep -q "notify-send Desktop theme could not load win98:.*ThisWin98IsDeliberatelyBroken" "$work/run3/commands.log"; then ok "broken win98 sends a notification naming the error"; else bad "no notification ($(cat "$work/run3/commands.log" 2>/dev/null))"; fi
expect "broken: one notification" "$(grep -c "notify-send Desktop theme could not load" "$work/run3/commands.log")" 1
grep -q "desktop-theme rollback win98 platinum" "$work/run3/commands.log" && ok "theme-name rolled back to platinum" || bad "no rollback"
expect "theme-name file" "$(cat "$XDG_STATE_HOME/mountainous/theme-name")" platinum
expect "broken: still Platinum, one slot" "$(loaded)" "platinum 1"
assert_layers "broken: after the rollback (the open menu closed)" platinum 0
session_stop
unset SESSION_COMPOSITOR

# The zone after a rollback, at the compositor that reports it.
SESSION_THEME=platinum . "$here/session.sh" "$broken" "$work/run4" 2880x1800
swaymsg -q output HEADLESS-1 bg '#204060' solid_color
name platinum
assert_zone platinum broken-before
name win98
for _ in $(seq 60); do grep -q "Desktop theme could not load" "$work/run4/commands.log" 2>/dev/null && break; sleep 0.1; done
assert_zone platinum broken-after
session_stop
trap - EXIT

echo "$pass checks passed"
[ $fail = 0 ] && echo WIN98_SWITCH_PASSED || { echo WIN98_SWITCH_FAILED; exit 1; }

#!/usr/bin/env bash
# The approved mock's interaction checks (/tmp/win98-mock/bin/check.sh),
# against the real Win98 Desktop in a private headless sway session: real
# pointer motion and clicks through a virtual pointer and sway's seat,
# real key presses through a virtual keyboard (wtype). checks.win98-desktop
# runs it; by hand:
#
#   modules/quickshell/theme-dev/win98/behaviour.sh <shell dir> [work dir]
#
# Needs sway, wtype, qs and a python3 with pywayland on PATH,
# WLR_PROTOCOL and WAYLAND_XML for pointer.py, and FONTCONFIG_FILE with
# W95FA Grid. Prints PASS/FAIL per check and exits non-zero on a
# failure or any QML warning.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:-$(mktemp -d "${TMPDIR:-/tmp}/win98-behaviour.XXXXXX")}")
# shellcheck source=session.sh
. "$here/session.sh" "$shell_dir" "$work" 2880x1800
trap 'echo quit >&3 2>/dev/null; session_stop' EXIT

fail=0
pass=0
for _ in $(seq 50); do w98 current | grep -q '"loaded":"win98"' && break; sleep 0.2; done
w98 set tb-normal >/dev/null
sleep 1.5

# A virtual pointer gives the seat a pointer (pointer.py).
mkfifo "$work/pointer"
python3 "$here/pointer.py" "$work/pointer" 1920 1200 > "$work/pointer.log" 2>&1 &
session_pids+=($!)
exec 3>"$work/pointer"
for _ in $(seq 50); do grep -q ready "$work/pointer.log" && break; sleep 0.1; done
grep -q ready "$work/pointer.log" || { cat "$work/pointer.log" >&2; echo "no virtual pointer" >&2; exit 1; }
at() { echo "move $1 $2" >&3; sleep 0.25; }
# The centre of a taskbar control, in logical px.
centre() {
  w98 places | python3 -c 'import json,sys; d=json.load(sys.stdin); p=d[sys.argv[1]]; print(round(p["x"]+p["w"]/2), round(1200 - d["barHeight"]/2))' "$1"
}
move() { at $(centre "$1"); }
click_at() { at "$1" "$2"; echo down >&3; sleep 0.05; echo up >&3; sleep 0.3; }
click() { click_at $(centre "$1"); }
# Wait (up to 3 s) until the open menu is $1 ("" for none), so a slow
# machine does not race the next event against a surface still mapping.
settle() { for _ in $(seq 30); do w98 menu | grep -q "open=$1\$" && break; sleep 0.1; done; sleep 0.15; }
item() { local r=""; for _ in $(seq 20); do r=$(w98 item "$1" "$2"); [ -n "$r" ] && break; sleep 0.1; done; echo "$r"; }
key() { wtype -k "$1"; sleep 0.2; }
letter() { wtype "$1"; sleep 0.2; }
check() {
  local got
  got="$(w98 menu) vol=$(w98 volume) picker=$(w98 picker)"
  if echo "$got" | grep -qE -- "$2"; then echo "PASS $1 -> $got"; pass=$((pass + 1));
  else echo "FAIL $1 -> $got (want $2)"; fail=1; fi
}

move vol;                                   check 'hover with nothing open does nothing' 'open= '
click start; settle start;                  check 'click Start opens it' 'open=start'
at $(item 0 Programs); at $(item 1 Internet); check 'hover cascades Programs > Internet' 'path=Programs/Internet .*open=start'
key Escape;                                 check 'Esc closes one submenu level' 'path=Programs cursor=Internet open=start'
move vol;                                   check 'hover tray icon while Start is open switches to Sound' 'open=vol'
for id in bt wifi bri oci disk builder ntf; do
  move "$id";                               check "hover switches to $id" "open=$id"
done
move clock;                                 check 'hover switches to the clock' 'open=clock'
move vol; key Right; key Right;             check 'Right x2: 42 -> 52' 'open=vol vol=52'
for _ in 1 2 3 4 5 6 7 8 9 10; do key Right; done
                                            check 'volume caps at 100 (wpctl rule)' 'vol=100'
key Escape;                                 check 'Esc closes the window' 'open= vol'
click ntf; settle ntf; click ntf; settle '';                       check 'second click on the same icon closes it' 'open= vol'
click wifi; settle wifi; click_at 600 400; settle '';               check 'click outside closes' 'open= vol'
click start; settle start; at $(item 0 Settings); click_at $(item 1 Display...); sleep 0.5
                                            check 'Start > Settings > Display... opens the picker' 'picker=open'
key Escape;                                 check 'Esc closes the picker' 'picker=closed'
click start; settle start; at 900 300
key Down;                                   check 'keyboard: Down selects the first item' 'path= cursor=Programs open=start'
key Up;                                     check 'keyboard: Up wraps to the last item' 'path= cursor=Log Off simon... open=start'
letter p;                                   check 'keyboard: P opens Programs' 'path=Programs cursor=Accessories'
key Down; key Down; key Right;              check 'keyboard: Down x2, Right opens Internet' 'path=Programs/Internet cursor=Chromium'
letter s;                                   check 'keyboard: S selects Signal' 'cursor=Signal'
letter s;                                   check 'keyboard: S again cycles to Sunshine' 'cursor=Sunshine'
key Left;                                   check 'keyboard: Left closes Internet, Internet stays selected' 'path=Programs cursor=Internet'
key Escape; key Escape;                     check 'keyboard: Esc twice closes Start' 'open= vol'

# The picker: Cancel leaves the theme alone; Apply commits through the
# shared model (desktop-theme apply).
w98 set pk-win98-light >/dev/null; sleep 1.2
wtype -M alt s -m alt; sleep 0.2; key Down    # Scheme: Dark grey
click_at $(w98 control pickerCancel)
sleep 0.5
grep -q "desktop-theme apply" "$work/commands.log" 2>/dev/null && { echo "FAIL Cancel applied a theme"; fail=1; } || { echo "PASS Cancel changes nothing"; pass=$((pass + 1)); }
w98 set pk-win98-light >/dev/null; sleep 1.2
wtype -M alt s -m alt; sleep 0.2; key Down
click_at $(w98 control pickerApply)
sleep 0.8
if grep -q "desktop-theme apply win98 dark off" "$work/commands.log" 2>/dev/null; then echo "PASS Apply commits win98 dark"; pass=$((pass + 1));
else echo "FAIL Apply did not commit ($(cat "$work/commands.log" 2>/dev/null | tr '\n' ' '))"; fail=1; fi
check 'Apply keeps the window open' 'picker=open'

if grep -E "WARN scene|TypeError|ReferenceError" "$work/qs.log" >&2; then echo "FAIL QML warnings" >&2; fail=1; fi
echo "$pass checks passed"
[ $fail = 0 ] && echo WIN98_BEHAVIOUR_PASSED || { echo WIN98_BEHAVIOUR_FAILED; exit 1; }

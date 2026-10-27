#!/usr/bin/env bash
# The Win98 Find window (Super+P) and Internet Explorer's Open dialog
# (Ctrl+L), against the real Win98 Desktop in private headless sway
# sessions (session.sh), with real key presses (wtype) and a virtual
# pointer (pointer.py). The omni service is OmniFixture.qml: the real entry
# rules (find-model.js), with runs and navigations written to a log.
#
#   behaviour  the claim and its release on a theme swap; Super+P opens Find
#              above Start with the last window chosen; typing filters;
#              Down/Up; Ctrl+1/2/3; Look in by keys and by pointer; Esc and
#              Backspace leave the scope, then close; a held Backspace stops
#              at the empty field; Enter, Open and a double click run a row;
#              Ctrl+L opens Open; Open prefills and selects the address,
#              lists open pages as you type and navigates; Backspace on its
#              empty field goes back to Find; Start > Find and Run... open
#              Find; a click outside closes and dismisses the service.
#   geometry   at 1920x1200, 1280x360, 1280x300, 640x360, 360x640 and 360x800 logical
#              px: the window above the taskbar, inside the screen; every
#              control inside the window; Look in's list and Open's list
#              inside the screen and clear of the taskbar; at least three
#              rows; the chosen row in view after 20 Downs.
#
#   modules/quickshell/theme-dev/win98/find.sh <shell dir> [work dir]
#
# Needs sway, wtype, qs, python3 with pywayland on PATH, WLR_PROTOCOL and
# WAYLAND_XML for pointer.py, FONTCONFIG_FILE with W95FA Grid.
# checks.win98-desktop runs it.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:-$(mktemp -d "${TMPDIR:-/tmp}/win98-find.XXXXXX")}")
mkdir -p "$work"
fail=0
pass=0
session_pids=()
trap '{ echo quit >&3; } 2>/dev/null || true; session_stop 2>/dev/null || true' EXIT

session() {  # session <logical W> <logical H>
  # shellcheck source=session.sh
  . "$here/session.sh" "$shell_dir" "$work/$1x$2" "$(( $1 * 3 / 2 ))x$(( $2 * 3 / 2 ))"
  for _ in $(seq 100); do w98 current | grep -q '"loaded":"win98"' && break; sleep 0.2; done
  for _ in $(seq 100); do w98 places | grep -q '"start"' && break; sleep 0.2; done
  sleep 0.5
}
# state <id>: set a find-states.js state and wait until its view is up.
state() {
  w98 set "$1" >/dev/null
  sleep 0.3
  for _ in $(seq 60); do w98 current | grep -q '"settled":true' && break; sleep 0.1; done
  sleep 0.5
}
# expect <label> <python expression over f (w98 find)>
expect() {
  local got ok
  sleep 0.25
  for _ in $(seq 15); do
    got=$(w98 find)
    ok=$(printf '%s' "$got" | python3 -c 'import json,sys; f=json.load(sys.stdin); print("ok" if eval(sys.argv[1]) else "no")' "$2" 2>&1) || ok="no"
    [ "$ok" = ok ] && break
    sleep 0.2
  done
  if [ "$ok" = ok ]; then echo "PASS $1"; pass=$((pass + 1)); else echo "FAIL $1 -> $got (want $2)"; fail=1; fi
}
logged() {  # logged <label> <text the harness log must hold>
  local got=""
  for _ in $(seq 20); do got=$(w98 commands); case "$got" in *"$2"*) break ;; esac; sleep 0.15; done
  case "$got" in *"$2"*) echo "PASS $1"; pass=$((pass + 1)) ;; *) echo "FAIL $1 -> ${got: -300} (want $2)"; fail=1 ;; esac
}
key() { wtype -k "$1"; sleep 0.2; }
mods() { local m=$1 k=$2; wtype -M "$m" -k "$k" -m "$m"; sleep 0.25; }
type_() { wtype "$1"; sleep 0.3; }

# ---------------------------------------------------------------- behaviour
session 1920 1200
mkfifo "$work/pointer"
python3 "$here/pointer.py" "$work/pointer" 1920 1200 > "$work/pointer.log" 2>&1 &
session_pids+=($!)
exec 3>"$work/pointer"
for _ in $(seq 50); do grep -q ready "$work/pointer.log" && break; sleep 0.1; done
grep -q ready "$work/pointer.log" || { cat "$work/pointer.log" >&2; echo "no virtual pointer" >&2; exit 1; }
at() { echo "move $1 $2" >&3; sleep 0.25; }
click_at() { at "$1" "$2"; echo down >&3; sleep 0.05; echo up >&3; sleep 0.3; }
dbl_at() { at "$1" "$2"; echo down >&3; sleep 0.03; echo up >&3; sleep 0.06; echo down >&3; sleep 0.03; echo up >&3; sleep 0.4; }
control() { local r=""; for _ in $(seq 20); do r=$(w98 findControl "$1"); [ -n "$r" ] && break; sleep 0.1; done; echo "$r"; }
item() { local r=""; for _ in $(seq 20); do r=$(w98 item "$1" "$2"); [ -n "$r" ] && break; sleep 0.1; done; echo "$r"; }

state f-rest
expect 'the active Win98 Desktop claims the omni view' 'f["claimed"] and f["views"] == 1'
expect 'Super+P: Find opens with the last window chosen' 'f["open"] == "find" and f["item"].startswith("Win98FindWindow") and f["scope"] == "all" and f["current"].startswith("Pull requests")'
type_ zed
expect 'typing filters the rows' 'f["query"] == "zed" and f["current"] == "Zed"'
key Down
expect 'Down moves the selection' 'f["current"] == "bar-plan.js - mountainous"'
key Up
expect 'Up moves it back' 'f["current"] == "Zed"'
mods ctrl 2
expect 'Ctrl+2: the Windows scope, the text cleared' 'f["mode"] == "window" and f["scope"] == "win" and f["query"] == ""'
key Escape
expect 'Esc leaves the scope' 'f["open"] == "find" and f["mode"] == "root"'
key Escape
expect 'Esc again closes and dismisses the service' 'f["open"] == "" and not f["shown"]'

# A held Backspace stops at the empty field; a new press leaves the scope.
w98 omniCall mode window >/dev/null; sleep 0.6
type_ ab
expect 'Windows scope with "ab"' 'f["mode"] == "window" and f["query"] == "ab"'
# One wtype holds the key: a keyboard that goes away releases its keys.
wtype -P BackSpace -s 1600 -p BackSpace; sleep 0.3
expect 'a held Backspace empties the field and stays in the scope' 'f["open"] == "find" and f["mode"] == "window" and f["query"] == ""'
key BackSpace
expect 'a new Backspace leaves the scope' 'f["open"] == "find" and f["mode"] == "root"'
key BackSpace
expect 'Backspace on All closes' 'f["open"] == "" and not f["shown"]'

# Look in, by keys and by the pointer.
state f-rest
mods alt Down
expect 'Alt+Down opens Look in' 'f["drop"]'
key Down; key Down; key Return
expect 'Down, Down, Enter: Windows' 'not f["drop"] and f["scope"] == "win"'
click_at $(control findScope)
expect 'a click on Look in opens it' 'f["drop"]'
click_at $(control findDrop | awk '{print $1, $2 + 20}')
expect 'a click on a scope row picks it' 'not f["drop"] and f["scope"] == "cmd"'
mods ctrl 1
expect 'Ctrl+1: Applications' 'f["scope"] == "app"'
key Escape; key Escape
expect 'closed' 'f["open"] == ""'

# Running rows: Enter, the Open button, a double click.
state f-rest
key Return
logged 'Enter runs the chosen window' 'omni activate Pull requests'
expect 'and the window closes' 'f["open"] == "" and not f["shown"]'
state f-rest
key Down
click_at $(control findOpen)
logged 'Open runs the chosen row' 'omni activate Signal'
state f-rest
dbl_at $(control findList | awk '{print $1, $2}')
expect 'a double click runs a row and closes' 'f["open"] == "" and not f["shown"]'
state f-rest
click_at $(control findClose)
expect 'Close closes' 'f["open"] == "" and not f["shown"]'
state f-rest
click_at 1700 300
expect 'a click outside closes and dismisses the service' 'f["open"] == "" and not f["shown"]'

# Ctrl+L: Open, from Find, on a terminal: a new window, nothing prefilled.
state f-rest
mods ctrl l
expect 'Ctrl+L in Find opens Open' 'f["open"] == "address" and f["item"].startswith("Win98OpenDialog") and f["mode"] == "nav"'
expect 'on a terminal Open says a new window' '"new window" in f["dest"] and f["address"] == ""'
key BackSpace
expect 'Backspace on the empty field goes back to Find' 'f["open"] == "find" and f["mode"] == "root"'
key Escape
# On a web app: the address prefilled and selected, typing replaces it.
state a-open
expect 'Ctrl+L on a web app: Open with its address' 'f["open"] == "address" and f["address"] == "https://github.com/simonwjackson/mountainous/pulls" and "this window" in f["dest"]'
type_ git
expect 'typing replaces the address and lists the matching pages' 'f["list"] and f["pages"] == 2 and f["address"] == "git"'
key Down
expect 'Down picks the first page' 'f["pick"] == 0 and f["address"].startswith("https://github.com/simonwjackson/mountainous")'
key Escape
expect 'Esc closes the list first' 'f["open"] == "address" and not f["list"]'
key Return
logged 'Enter navigates the caller' 'omni navigate git caller=Pull requests'
expect 'and Open closes' 'f["open"] == "" and not f["shown"]'
state a-open
click_at $(control openDrop)
expect 'the drop button lists every open page' 'f["list"] and f["pages"] == 5'
click_at $(control openList | awk '{print $1, $2}')
logged 'a click on a page navigates to it' 'omni navigate https://'
state a-open
key Escape
expect 'Esc closes Open' 'f["open"] == "" and not f["shown"]'

# Start > Find > Windows... and Start > Run...
state f-rest; key Escape; sleep 0.3
w98 set tb-normal >/dev/null; sleep 0.8
click_at $(w98 places | python3 -c 'import json,sys; d=json.load(sys.stdin); p=d["start"]; print(round(p["x"]+p["w"]/2), round(1200 - d["barHeight"]/2))')
at $(item 0 Find); at $(item 1 Windows...)
click_at $(item 1 Windows...)
expect 'Start > Find > Windows... opens Find in Windows' 'f["open"] == "find" and f["scope"] == "win"'
key Escape; key Escape
click_at $(w98 places | python3 -c 'import json,sys; d=json.load(sys.stdin); p=d["start"]; print(round(p["x"]+p["w"]/2), round(1200 - d["barHeight"]/2))')
click_at $(item 0 Run...)
expect 'Start > Run... opens Find in All' 'f["open"] == "find" and f["scope"] == "all"'
key Escape

# A theme swap releases the claim; Platinum claims it; back again.
printf 'platinum\n' > "$XDG_STATE_HOME/mountainous/theme-name"
for _ in $(seq 100); do w98 current | grep -q '"loaded":"platinum"' && break; sleep 0.2; done
sleep 1
expect 'under Platinum one view claims the service (Win98 released it)' 'f["views"] == 1'
printf 'win98\n' > "$XDG_STATE_HOME/mountainous/theme-name"
for _ in $(seq 100); do w98 current | grep -q '"loaded":"win98"' && break; sleep 0.2; done
sleep 1
expect 'back under Win98: one claim, Win98s' 'f["views"] == 1 and f["claimed"]'
logged 'the log shows the release' 'omni release'

if grep -E "WARN scene|TypeError|ReferenceError" "$work/1920x1200/qs.log" >&2; then echo "FAIL QML warnings" >&2; fail=1; fi
echo quit >&3 || true
exec 3>&-
session_stop

# ---------------------------------------------------------------- geometry
# check <label> <python expression over g (w98 findGeometry), W, H, B>
check() {
  local out
  out=$(w98 findGeometry | python3 -c '
import json, sys
g = json.load(sys.stdin); W, H, B = g["w"], g["h"], g["bar"]; e = 0.51
P = g["parts"]; win = g.get("window")
ins = lambda r, x0=0, y0=0, x1=None, y1=None: r is not None and r["x"] >= x0 - e and r["y"] >= y0 - e \
    and r["x"] + r["w"] <= (W if x1 is None else x1) + e and r["y"] + r["h"] <= (H if y1 is None else y1) + e
inwin = lambda n: n in P and ins(P[n], win["x"], win["y"], win["x"] + win["w"], win["y"] + win["h"])
ok = eval(sys.argv[1])
if not ok: open(sys.argv[2], "w").write(json.dumps(g, indent=1))
print("ok" if ok else "FAIL (geometry in " + sys.argv[2] + ")")' "$2" "$work/fail-$pass-$fail.json" 2>&1) || out="FAIL $out"
  if [ "${out%% *}" = ok ]; then echo "PASS $1"; pass=$((pass + 1)); else echo "FAIL $1: $out"; fail=1; fi
}
ABOVE='ins(win, y1=H - B)'
for size in 1920x1200 1280x360 1280x300 640x360 360x640 360x800; do
  w=${size%x*}; h=${size#*x}
  session "$w" "$h"
  state f-rest
  check "Find at ${size}: above the taskbar, inside the screen" "$ABOVE"
  check "Find at ${size}: field, Look in, list, Open and Close inside the window" \
    'all(inwin(n) for n in ("findField", "findScope", "findList", "findOpen", "findClose"))'
  check "Find at ${size}: at least three rows" 'g["plan"]["list"] >= 48'
  check "Find at ${size}: Open and Close clear of the list and of each other" \
    'all(P[b]["y"] + P[b]["h"] <= P["findList"]["y"] + e or P[b]["y"] >= P["findList"]["y"] + P["findList"]["h"] - e for b in ("findOpen", "findClose")) \
     and (P["findOpen"]["x"] + P["findOpen"]["w"] <= P["findClose"]["x"] + e or P["findOpen"]["y"] + P["findOpen"]["h"] <= P["findClose"]["y"] + e)'
  if [ "$size" = 1280x300 ]; then
    check "Find at ${size}: short and wide, one criteria row in a wider window" '"criteria on one row" in g["plan"]["steps"] and g["plan"]["width"] == 520'
  fi
  state f-scope-pop
  check "Find at ${size}: Look in's list inside the screen, clear of the taskbar" 'ins(P.get("findDrop"), y1=H - B)'
  state f-long
  expect "Find at ${size}: 20 Downs, the chosen row scrolled into view" 'f["inView"] and f["scrollY"] > 0'
  # The first row is cut: its full name shows in a tip clear of the row.
  state f-cut
  TIP='(lambda t, top, bot: t is not None and ins(t) and (t["y"] >= bot - e or t["y"] + t["h"] <= top + e))(P.get("findTip"), P["findList"]["y"] + 19 * 4 / 3, P["findList"]["y"] + 35 * 4 / 3)'
  if [ "$size" = 1920x1200 ] || [ "$size" = 360x800 ]; then
    check "Find at ${size}: a cut name shows in full, clear of its row" "$TIP"
  else
    check "Find at ${size}: a cut name's tip, if shown, is clear of its row" "P.get('findTip') is None or $TIP"
  fi
  state a-open
  check "Open at ${size}: above the taskbar, inside the screen" "$ABOVE"
  check "Open at ${size}: field, OK and Cancel inside the window" \
    'all(inwin(n) for n in ("openField", "openOk", "openCancel"))'
  state a-list
  check "Open at ${size}: its list inside the screen, clear of the taskbar" 'ins(P.get("openList"), y1=H - B)'
  if grep -E "WARN scene|TypeError|ReferenceError" "$work/${size}/qs.log" >&2; then echo "FAIL QML warnings at $size" >&2; fail=1; fi
  session_stop
done

echo "$pass checks passed"
[ $fail = 0 ] && echo WIN98_FIND_PASSED || { echo WIN98_FIND_FAILED; exit 1; }

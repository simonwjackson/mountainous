#!/usr/bin/env bash
# The Win98 taskbar and session parity items (the approved parity mock,
# /tmp/tandem/win98-parity-mock, items 3 to 9), against the real Win98
# Desktop in a private headless sway session: a virtual pointer and
# keyboard for what a person does, the harness's IPC for what the
# compositor sends (the windows menu call, chrome cycle messages, a volume
# or brightness change).
#
#   - minimized windows keep their raised button; a click on the active
#     button minimizes it, on a minimized one restores it alone;
#   - a button's right click: Restore, Move to, Minimize, Maximize, Close;
#     Move to names each page by its apps (never a number) and, on a
#     minimized window, changes its home only;
#   - no page number anywhere: drawn strings, menu rows, tooltips, and no
#     text on a band's divider (its tooltip names the band's apps);
#   - the taskbar's own right click: Minimize All, Minimize Other, Restore
#     All, Find...;
#   - the windows menu IPC: an address or the focused window, at a point or
#     at its own corner; anything else is ignored;
#   - held Super+Tab: the Cool Switch, its order, stale messages, commit
#     and cancel, a minimized window restored by a commit;
#   - Start: Lock at once, Shut Down Myoko (remembered choice, the warning
#     line, modal checker, the same commands), Log Off's confirmation,
#     System Properties, Documents and Favorites through Launcher, (Empty);
#   - the volume and brightness pop-up: placement, 1.5 s, Muted, and no
#     pop-up while a window is open or for values a state sheet loads.
#
# Session commands and Launcher's scopes are logging stubs (session.sh):
# nothing locks, sleeps, reboots, powers off, logs out or starts an app.
# checks.win98-desktop runs it; by hand:
#
#   modules/quickshell/theme-dev/win98/taskbar.sh <shell dir> [work dir]
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:-$(mktemp -d "${TMPDIR:-/tmp}/win98-taskbar.XXXXXX")}")
# shellcheck source=session.sh
. "$here/session.sh" "$shell_dir" "$work" 2880x1800
trap 'echo quit >&3 2>/dev/null; session_stop' EXIT

fail=0
pass=0
for _ in $(seq 50); do w98 current | grep -q '"loaded":"win98"' && break; sleep 0.2; done
w98 set tb-normal >/dev/null
for _ in $(seq 100); do w98 places | grep -q '"vol"' && w98 places | grep -q '"clock"' && break; sleep 0.2; done
sleep 1

mkfifo "$work/pointer"
python3 "$here/pointer.py" "$work/pointer" 1920 1200 > "$work/pointer.log" 2>&1 &
session_pids+=($!)
exec 3>"$work/pointer"
for _ in $(seq 50); do grep -q ready "$work/pointer.log" && break; sleep 0.1; done
grep -q ready "$work/pointer.log" || { cat "$work/pointer.log" >&2; echo "no virtual pointer" >&2; exit 1; }

at() { echo "move $1 $2" >&3; sleep 0.25; }
centre() {
  for _ in $(seq 30); do w98 places | grep -q "\"$1\"" && break; sleep 0.1; done
  w98 places | python3 -c 'import json,sys; d=json.load(sys.stdin); p=d[sys.argv[1]]; print(round(p["x"]+p["w"]/2), round(1200 - d["barHeight"]/2))' "$1"
}
click_at() { at "$1" "$2"; echo down >&3; sleep 0.05; echo up >&3; sleep 0.35; }
click() { click_at $(centre "$1"); }
right() { at $(centre "$1"); echo right >&3; sleep 0.35; }
settle() { for _ in $(seq 30); do w98 menu | grep -q "open=$1\$" && break; sleep 0.1; done; sleep 0.2; }
item() { local r=""; for _ in $(seq 20); do r=$(w98 item "$1" "$2"); [ -n "$r" ] && break; sleep 0.1; done; echo "$r"; }
key() { wtype -k "$1"; sleep 0.25; }
letter() { wtype "$1"; sleep 0.25; }
ok() { echo "PASS $1"; pass=$((pass + 1)); }
bad() { echo "FAIL $1"; fail=1; }
# check <label> <python expression over T (tasks), L (the harness log), C (commands.log), M (menu line), P (popup), Y (cycle)>
check() {
  local out
  out=$(python3 - "$2" <<EOF 2>&1
import json, sys
T = json.loads('''$(w98 tasks)''')
L = '''$(w98 commands)'''.split("|")
C = open("$work/commands.log").read() if __import__("os").path.exists("$work/commands.log") else ""
M = '''$(w98 menu)'''
P = json.loads('''$(w98 popup)''')
Y = json.loads('''$(w98 cycleState)''')
ok = eval(sys.argv[1])
print("ok" if ok else "no: tasks=%s menu=%s log=%s popup=%s cycle=%s" % (json.dumps([[t["i"], t["page"], t["min"], t["active"]] for t in T]), M, L[-6:], P, Y))
EOF
)
  if [ "$out" = ok ]; then ok "$1"; else bad "$1 -> $out"; fi
}
# Pages are never numbered (Simon): no drawn string, menu row or tooltip
# says "page 3", and no text is drawn on a page band's divider.
nonumbers() {
  local out
  out=$(w98 strings | python3 -c '
import json, re, sys
d = json.load(sys.stdin)
bad = [t for t in d["drawn"] + d["tips"] if re.search(r"\bpage\s*\d", t, re.I)]
bands = [b for b in d["bands"] if b["text"] or re.fullmatch(r"\s*\d+\s*", b["tip"] or "")]
print("ok" if not bad and not bands and d["bands"] else "no: %s %s %s" % (bad[:5], bands[:3], len(d["bands"])))')
  if [ "$out" = ok ]; then ok "$1: no page number drawn"; else bad "$1: $out"; fi
}
mins() { w98 tasks | python3 -c 'import json,sys; print(" ".join(str(t["i"]) for t in json.load(sys.stdin) if t["min"]))'; }
reset() { w98 set tb-normal >/dev/null; sleep 0.8; }

# ---------------------------------------------------------------- minimize and restore
reset
click win0;  check 'a click on the active button minimizes it (shared hide)' 'T[0]["min"] and not T[0]["active"] and "hide 0" in L'
check 'the minimized window keeps its button in its home band' '[t["i"] for t in T] == [0, 1, 2, 3, 4] and T[0]["page"] == 1'
w98 places | grep -q '"win0"' && ok 'its button is still on the taskbar' || bad 'no win0 button'
click win0;  check 'a click on a minimized button restores it, focused' 'not T[0]["min"] and T[0]["active"] and L[-1] == "show 0 1"'
click win1;  check 'a click on another button brings it forward' 'T[1]["active"] and not T[1]["min"] and "activate 1" in L'
reset
nonumbers 'the taskbar'
tips=$(w98 strings | python3 -c 'import json,sys; print("|".join(b["tip"] for b in json.load(sys.stdin)["bands"]))')
[ "$tips" = "Ghostty and Chromium|Signal and Zed|OBS Studio" ] && ok "each divider's tooltip names its apps ($tips)" || bad "divider tooltips: $tips"
click start; settle start; letter w; settle start
nonumbers 'Start > Windows'
w98 menu | grep -q 'path=Windows ' && ok 'Start > Windows opens' || bad "Windows: $(w98 menu)"
key Escape; key Escape; settle ''

# ---------------------------------------------------------------- the window menu
reset
right win2; settle winmenu
check 'a right click on a button opens its window menu' 'M.endswith("open=winmenu")'
at $(item 0 "Move to"); check 'Move to cascades' 'M.startswith("path=Move to ")'
nonumbers 'the window menu and Move to'
[ -n "$(item 1 "Beside Ghostty and Chromium")" ] && [ -n "$(item 1 "Beside Zed")" ] && [ -n "$(item 1 "New Page")" ] \
  && ok 'Move to names each page by its other apps, then New Page' || bad 'Move to rows'
click_at $(item 1 "Beside OBS Studio");  settle ''
check 'Move to > Beside OBS Studio moves the window, the menu closes' 'L[-1] == "move 2 3" and M.endswith("open=")'
right win1; settle winmenu; letter n; settle ''
check 'Mi&nimize from the window menu' 'T[1]["min"] and L[-1] == "hide 1"'
right win1; settle winmenu
at $(item 0 "Move to"); click_at $(item 1 "Beside Zed"); settle ''
check 'Move to on a minimized window changes only its home' 'L[-1] == "home 1 2" and [t for t in T if t["i"] == 1][0]["page"] == 2 and [t for t in T if t["i"] == 1][0]["min"]'
right win1; settle winmenu; letter r; settle ''
check 'Restore from the window menu: back on its new home page' 'L[-1] == "show 1 2" and not [t for t in T if t["i"] == 1][0]["min"]'
reset
right win3; settle winmenu; letter x; settle ''
sleep 0.3
grep -q 'hl.dsp.focus({ window = "address:0x1003" }) ; dispatch hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })' "$work/commands.log" \
  && ok 'Ma&ximize focuses that window and maximizes it' || bad "Maximize: $(tail -2 "$work/commands.log")"
right win4; settle winmenu; key Up; key Return; settle ''
check 'Close (Up from nothing reaches the last item, Enter)' 'L[-1] == "close 4"'
right win0; settle winmenu; key Escape; settle ''
check 'Esc closes the window menu' 'M.endswith("open=")'

# ---------------------------------------------------------------- the taskbar's own menu
reset
click_at 1500 1185; sleep 0.2
check 'a left click on the empty taskbar opens nothing' 'M.endswith("open=")'
at 1500 1185; echo right >&3; sleep 0.4; settle tbmenu
check 'a right click on the empty taskbar opens its menu' 'M.endswith("open=tbmenu")'
nonumbers 'the taskbar menu'
click_at $(item 0 "Minimize Other Windows"); settle ''
check 'Minimize Other Windows keeps the front window' 'sorted(t["i"] for t in T if t["min"]) == [1, 2, 3, 4] and not T[0]["min"]'
at 1500 1185; echo right >&3; sleep 0.4; settle tbmenu
click_at $(item 0 "Minimize All Windows"); settle ''
check 'Minimize All Windows: every window, every button stays' 'all(t["min"] for t in T) and len(T) == 5'
at 1500 1185; echo right >&3; sleep 0.4; settle tbmenu
click_at $(item 0 "Restore All Windows"); settle ''
check 'Restore All Windows (Show All) brings every one back to its page' 'not any(t["min"] for t in T) and [t["page"] for t in T] == [1, 1, 2, 2, 3]'
at 1500 1185; echo right >&3; sleep 0.4; settle tbmenu
click_at $(item 0 "Find..."); settle ''
settle find
check 'Find... opens Super+P (the Find window)' 'M.endswith("open=find")'
key Escape; settle ''

# ---------------------------------------------------------------- the windows menu IPC
reset
w98 windowMenu "" -1 -1 >/dev/null; settle winmenu
pos=$(w98 geometry | python3 -c 'import json,sys; p=json.load(sys.stdin)["panels"][0]; print(round(p["x"]), round(p["y"]))')
[ "$pos" = "4 40" ] && ok "windows menu '' -1 -1: the focused window's menu at its corner ($pos)" || bad "windows menu '' -1 -1 at $pos"
w98 windowMenu 1002 700 300 >/dev/null; sleep 0.4
pos=$(w98 geometry | python3 -c 'import json,sys; p=json.load(sys.stdin)["panels"][0]; print(round(p["x"]), round(p["y"]))')
[ "$pos" = "700 300" ] && ok "windows menu 1002 700 300: at the point" || bad "windows menu at a point: $pos"
w98 windowMenu 0x1003 1915 1190 >/dev/null; sleep 0.4
w98 geometry | python3 -c '
import json,sys; g=json.load(sys.stdin); p=g["panels"][0]
sys.exit(0 if p["x"] + p["w"] <= g["w"] + 0.5 and p["y"] + p["h"] <= g["h"] - g["places"]["barHeight"] + 0.5 else 1)' \
  && ok 'windows menu at the screen corner: moved up and left, inside' || bad 'windows menu at the corner: outside'
w98 closeAll >/dev/null; sleep 0.3
[ "$(w98 windowMenu zz 10 10)" = invalid ] && ok 'windows menu with a non-hex address: ignored' || bad 'non-hex address accepted'
[ "$(w98 windowMenu ffff 10 10)" = none ] && ok 'windows menu for no live window: ignored' || bad 'unknown address accepted'
check 'nothing opened for them' 'M.endswith("open=")'

# ---------------------------------------------------------------- held Super+Tab
reset
seq=$(( $(date +%s) % 100000 * 10 ))
w98 cycle step 2 $((seq + 1)) >/dev/null; sleep 0.4
check 'step 2: the Cool Switch opens on the window after the quick press' 'Y["open"] and Y["box"] is not None and Y["target"] == Y["order"][2 % len(Y["order"])]'
w98 geometry | python3 -c '
import json,sys; g=json.load(sys.stdin); c=g["cool"]; W,H=g["w"],g["h"]-g["places"]["barHeight"]
sys.exit(0 if abs(c["x"] + c["w"]/2 - W/2) <= 1 and abs(c["y"] + c["h"]/2 - H/2) <= 1 else 1)' \
  && ok 'the Cool Switch stands in the middle above the taskbar' || bad 'Cool Switch not centred'
w98 cycle step 3 $((seq + 2)) >/dev/null; sleep 0.2
[ "$(w98 cycle step 2 $((seq + 1)))" = stale ] && ok 'an older step is dropped' || bad 'stale step accepted'
check 'step 3 holds' 'Y["target"] == Y["order"][3]'
nonumbers 'the Cool Switch'
t3=$(w98 cycleState | python3 -c 'import json,sys; print(json.load(sys.stdin)["target"])')
w98 cycle commit 3 $((seq + 4)) >/dev/null; sleep 0.4
check 'commit: the box closes and the window comes forward' 'not Y["open"] and L[-1] == "activate %d" % (int("'"$t3"'") - 1000)'
[ "$(w98 cycle step 3 $((seq + 3)))" = stale ] && ok 'a step that arrives after its commit is dropped' || bad 'late step accepted'
check 'the late step opened nothing' 'not Y["open"]'
w98 cycle step 2 $((seq + 5)) >/dev/null; sleep 0.2
w98 cycle cancel 0 $((seq + 6)) >/dev/null; sleep 0.3
check 'cancel closes it and switches nothing' 'not Y["open"] and L[-1] == "activate %d" % (int("'"$t3"'") - 1000)'
# A minimized window takes part; a commit on it restores it alone.
reset
right win3; settle winmenu; letter n; settle ''
w98 cycle step 2 $((seq + 7)) >/dev/null; sleep 0.2
n=1; for _ in 1 2 3 4 5 6; do
  t=$(w98 cycleState | python3 -c 'import json,sys; print(json.load(sys.stdin)["target"])')
  [ "$t" = 1003 ] && break
  n=$((n + 1)); w98 cycle step $((n + 1)) $((seq + 7 + n)) >/dev/null; sleep 0.15
done
w98 at cool rect:coolSwitchTitle | grep -q '(minimized)' && ok 'the title box says the window is minimized' || bad "title: $(w98 at cool rect:coolSwitchTitle)"
w98 cycle commit $((n + 1)) $((seq + 20)) >/dev/null; sleep 0.4
check 'a commit on a minimized window restores it' 'L[-1] == "show 3 2" and not T[3]["min"]'

# ---------------------------------------------------------------- Start: session
reset
click start; settle start; letter k; settle ''
sleep 0.3
grep -q '^loginctl lock-session$' "$work/commands.log" && ok 'Start > Lock Myoko locks at once (stubbed)' || bad "no lock: $(cat "$work/commands.log")"
click start; settle start; letter u; settle shutdown
check 'Start > Shut Down... opens Shut Down Myoko' 'M.endswith("open=shutdown")'
nonumbers 'Shut Down Myoko'
[ "$(w98 shutChoice)" = standby ] && ok 'it opens on Stand by the first time' || bad "first choice $(w98 shutChoice)"
w98 at shutdown rect:shutDownWarning | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)["text"].strip() == "" else 1)' \
  && ok 'Stand by: no warning line' || bad 'warning under Stand by'
click_at 300 300; sleep 0.3
check 'a click on the checker does nothing (modal)' 'M.endswith("open=shutdown")'
letter r; sleep 0.2
[ "$(w98 shutChoice)" = restart ] && ok 'R chooses Restart' || bad "R chose $(w98 shutChoice)"
w98 at shutdown rect:shutDownWarning | grep -q 'Open windows close without saving.' && ok 'Restart: the red warning line' || bad 'no warning under Restart'
key Down; [ "$(w98 shutChoice)" = logoff ] && ok 'Down moves the choice' || bad "Down chose $(w98 shutChoice)"
key Up
click_at $(w98 at shutdown shutDownOk); settle ''
sleep 0.3
grep -q '^systemctl reboot$' "$work/commands.log" && ok 'OK runs Restart (stubbed)' || bad "no reboot: $(tail -3 "$work/commands.log")"
[ "$(cat "$XDG_STATE_HOME/mountainous/win98-shut-down")" = restart ] && ok 'the choice is remembered on disk' || bad 'not remembered'
click start; settle start; letter u; settle shutdown
[ "$(w98 shutChoice)" = restart ] && ok 'the dialog opens on the last choice OK'"'"'d' || bad "reopened on $(w98 shutChoice)"
before=$(wc -l < "$work/commands.log")
key Escape; settle ''
[ "$(wc -l < "$work/commands.log")" = "$before" ] && ok 'Esc cancels and runs nothing' || bad 'Esc ran something'
click start; settle start; letter u; settle shutdown; letter b; click_at $(w98 at shutdown shutDownCancel); settle ''
[ "$(wc -l < "$work/commands.log")" = "$before" ] && ok 'Cancel runs nothing and keeps the old choice' || bad 'Cancel ran something'
[ "$(cat "$XDG_STATE_HOME/mountainous/win98-shut-down")" = restart ] && ok 'Cancel does not change the remembered choice' || bad 'Cancel changed it'
click start; settle start; letter u; settle shutdown; letter b; key Return; settle ''; sleep 0.3
grep -q '^systemctl suspend$' "$work/commands.log" && ok 'Stand by, Enter: suspends (stubbed)' || bad 'no suspend'
click start; settle start; letter u; settle shutdown; letter l; key Return; settle ''; sleep 0.3
grep -q 'hyprctl --instance 0 dispatch hl.dsp.exit()' "$work/commands.log" && ok 'Log off simon: the session exit (stubbed)' || bad 'no exit'
click start; settle start; letter l; settle logoff
check 'Start > Log Off simon... keeps its confirmation' 'M.endswith("open=logoff")'
letter n; settle ''

# ---------------------------------------------------------------- System Properties
click start; settle start; at $(item 0 Settings); click_at $(item 1 System...); settle sysprops
check 'Start > Settings > System... opens System Properties' 'M.endswith("open=sysprops")'
w98 geometry | python3 -c '
import json,sys; g=json.load(sys.stdin); w=g["window"]
sys.exit(0 if w and w.get("systemOk") and w.get("systemFacts") else 1)' && ok 'General: the facts and OK' || bad 'System Properties parts missing'
nonumbers 'System Properties'
key Return; settle ''
check 'Enter closes it' 'M.endswith("open=")'

# ---------------------------------------------------------------- Documents and Favorites
click start; settle start; letter d; settle start
check 'Documents opens with its first item' 'M.startswith("path=Documents cursor=Zed")'
key Return; settle ''; sleep 0.3
grep -q 'systemd-run --user --scope.* -- zeditor$' "$work/commands.log" && ok 'Documents > Zed launches through Launcher' || bad "no zeditor launch: $(grep systemd-run "$work/commands.log" | tail -1)"
click start; settle start; letter v; settle start
check 'Favorites lists the web apps by name' 'M.startswith("path=Favorites cursor=GitHub")'
key Return; settle ''; sleep 0.3
grep -q 'systemd-run .*--unit=app-webapp-github-.* -- chromium --app=https://github.com$' "$work/commands.log" && ok 'Favorites > GitHub launches the web app through Launcher' || bad "no web app launch: $(grep systemd-run "$work/commands.log" | tail -1)"
w98 lists empty >/dev/null; sleep 0.3
click start; settle start; letter d; settle start
check 'no recent applications: Documents holds (Empty), nothing selected' 'M.startswith("path=Documents cursor=- ")'
[ -n "$(item 1 "(Empty)")" ] && ok '(Empty) is shown' || bad 'no (Empty)'
key Escape; key Escape; settle ''
w98 lists full >/dev/null

# ---------------------------------------------------------------- the pop-up
reset
sleep 0.2
w98 setVolume 30 >/dev/null; sleep 0.3
check 'no pop-up for a value a state sheet just loaded (disarmed for 2 s)' 'P["id"] == ""'
sleep 2.2
w98 setVolume 55 >/dev/null; sleep 0.4
check 'a volume change shows the pop-up' 'P["id"] == "vol" and P["box"] is not None'
nonumbers 'the pop-up'
w98 geometry | python3 -c '
import json,sys; g=json.load(sys.stdin); b=g["popup"]; v=g["places"]["vol"]; top=g["h"]-g["places"]["barHeight"]
sys.exit(0 if b["y"] + b["h"] <= top + 0.5 and b["x"] >= 0 and b["x"] + b["w"] <= g["w"] + 0.5 and abs(b["x"] + b["w"]/2 - min(max(v["x"] + v["w"]/2, b["w"]/2), g["w"] - b["w"]/2)) <= 3 else 1)' \
  && ok 'the pop-up stands above the volume icon, inside the screen' || bad 'pop-up misplaced'
w98 at popup rect:volumePopupValue | grep -q '"55%"' && ok 'it shows the value' || bad "value: $(w98 at popup rect:volumePopupValue)"
sleep 1.6
check 'it goes after 1.5 s' 'P["id"] == ""'
w98 setMuted true >/dev/null; sleep 0.3
w98 at popup rect:volumePopupValue | grep -q '"Muted"' && ok 'mute shows Muted' || bad "muted: $(w98 at popup rect:volumePopupValue)"
w98 setMuted false >/dev/null
w98 setBrightness 35 >/dev/null; sleep 0.3
check 'a brightness change shows the brightness pop-up' 'P["id"] == "bri"'
click vol; settle vol
w98 setVolume 70 >/dev/null; sleep 0.3
check 'no pop-up while the Sound window is open' 'P["id"] == "" and M.endswith("open=vol")'
key Escape; settle ''

if grep -E "WARN scene|TypeError|ReferenceError" "$work/qs.log" >&2; then bad "QML warnings"; fi
echo "$pass checks passed"
[ $fail = 0 ] && echo WIN98_TASKBAR_PASSED || { echo WIN98_TASKBAR_FAILED; exit 1; }

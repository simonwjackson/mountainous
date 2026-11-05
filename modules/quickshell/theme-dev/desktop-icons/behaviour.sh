#!/usr/bin/env bash
# The desktop icon layer under a real Quickshell in a headless sway, with a
# virtual pointer and keyboard, against provider.js (checks.desktop-icons,
# and by hand). Never delivered.
#
#   behaviour.sh <shell dir> <work dir>
#
# Proves: the surface takes clicks on the desktop only (a window above it
# keeps its clicks), the keyboard on demand, select, rubber band, drag to
# Move, double-click to Open, the context menu, Tab and arrows through a
# cascade with the focused icon raised, Memphis asking before Delete with
# No as the way out, a resubscribe on a theme switch and on a display
# change, and no icons while the provider is down, then back.
#
# Needs sway, wtype, qs, node and a python3 with pywayland on PATH;
# WLR_PROTOCOL and WAYLAND_XML for pointer.py; FONTCONFIG_FILE.
set -euo pipefail
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:?work dir}")
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$work"
export SESSION_PROVIDER=node SESSION_FIXTURE=stub
# shellcheck source=session.sh
. "$here/session.sh" "$shell_dir" "$work" 2880x1800
trap session_stop EXIT

fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
# check <name> <js expression over s (current state) and log (provider messages)>
check() {
  local name=$1 expr=$2 state
  for _ in $(seq 30); do
    state=$(desk current)
    if node -e '
      const s = JSON.parse(process.argv[1]);
      const log = require("fs").existsSync(process.argv[2]) ? require("fs").readFileSync(process.argv[2], "utf8").split("\n").filter((l) => l.startsWith("< ")).map((l) => JSON.parse(l.slice(2))) : [];
      process.exit((' "$expr" ') ? 0 : 1);' "$state" "$work/provider-messages.log" 2>/dev/null; then ok "$name"; return 0; fi
    sleep 0.1
  done
  bad "$name: $(echo "$state" | head -c 600)"
}

desk_wait live || { cat "$work/qs.log"; exit 1; }
check "platinum: live with the stub's icons" 's.shown && s.input && s.icons.length === 8 && s.theme === "platinum"'
check "subscribed with the usable area under the menu bar" 'log.some((m) => m.type === "subscribe" && m.theme === "platinum" && m.screen.usable.y === 28 && m.screen.width === 1920 && m.screen.scale === 1.5)'

mkfifo "$work/pointer"
python3 "$here/../win98/pointer.py" "$work/pointer" 1920 1200 > "$work/pointer.log" 2>&1 &
session_pids+=($!)
exec 3>"$work/pointer"
for _ in $(seq 50); do grep -q ready "$work/pointer.log" && break; sleep 0.1; done
grep -q ready "$work/pointer.log" || { cat "$work/pointer.log"; exit 1; }
p() { echo "$*" >&3; sleep 0.15; }
click() { p move "$1" "$2"; p down; p up; }
key() { wtype -k "$1"; sleep 0.25; }

# A click on an icon selects it and gives the desktop the keyboard.
read -r x y <<<"$(desk where file:notes.txt)"
click "$x" "$y"
check "click selects" 'JSON.stringify(s.selection) === JSON.stringify(["file:notes.txt"])'
check "the desktop has the keyboard on demand" 's.activeFocus === true'
key Down
check "Down moves to the next icon" 'JSON.stringify(s.selection) === JSON.stringify(["file:Projects"])'
key Tab
check "Tab follows the snapshot order" 's.focus === "file:krita.desktop"'
key Return
check "Enter opens" 'log.some((m) => m.type === "open" && m.ids[0] === "file:krita.desktop")'

# An empty spot clears the selection; a band selects what it crosses.
click 900 700
check "a click on the desktop clears" 's.selection.length === 0'
read -r cx cy <<<"$(desk where computer)"
read -r tx ty <<<"$(desk where trash)"
p move 200 $((cy - 30)); p down; p move 150 $((cy + 10)); p move 4 $((ty + 10)); p up
check "rubber band" 's.selection.includes("computer") && s.selection.includes("ssh-hosts") && s.selection.includes("trash") && !s.selection.includes("file:Projects")'

# Drag to move: a Move with the new top-left, inside the usable area.
read -r x y <<<"$(desk where file:notes.txt)"
p move "$x" "$y"; p down; p move $((x + 40)) $((y + 10)); p move $((x + 300)) $((y + 20)); p up
check "drag sends Move" 'log.some((m) => m.type === "move" && m.moves.length === 1 && m.moves[0][0] === "file:notes.txt" && m.moves[0][1].x >= 300)'
check "the moved icon is drawn where the provider put it" 's.boxes["file:notes.txt"].x > 300'

# Drop onto the Trash: a Drop (the fixture asks to confirm; Platinum sends Trash at once).
read -r x y <<<"$(desk where file:Docs\ link)"
read -r tx ty <<<"$(desk where trash)"
p move "$x" "$y"; p down; p move $((x + 20)) $((y - 20)); p move "$tx" "$ty"; p up
check "drop on the Trash sends Drop" 'log.some((m) => m.type === "drop" && m.target === "trash" && m.ids[0] === "file:Docs link")'
check "Platinum moves to the Trash without asking" 's.alert === null && log.some((m) => m.type === "trash" && m.ids[0] === "file:Docs link") && !s.icons.includes("file:Docs link")'

# Double-click opens.
read -r x y <<<"$(desk where file:Projects)"
p move "$x" "$y"; p down; p up; p down; p up
check "double-click opens" 'log.some((m) => m.type === "open" && m.ids[0] === "file:Projects")'

# The context menu on the desktop, in Platinum's words; Escape closes it.
p move 900 700; p right
check "desktop menu" 'JSON.stringify(s.menu) === JSON.stringify(["Clean Up", "-", "Always snap to grid"])'
key Escape
check "Escape closes the menu" 's.menu === null'

# A window above the desktop keeps its clicks.
read -r x y <<<"$(desk where computer)"
desk window $((x - 60)) $((y - 60)) 300 200 >/dev/null
sleep 0.4
desk select "" >/dev/null
click "$x" "$y"
check "a click on a window never reaches the desktop" 's.selection.length === 0'
desk window 0 0 0 0 >/dev/null
sleep 0.3

# Memphis: resubscribe as win98; Delete asks first and No keeps the file.
theme win98 light
check "a theme switch resubscribes" 'log.some((m) => m.type === "subscribe" && m.theme === "win98" && m.screen.usable.y === 0 && m.screen.usable.height === 1200 - 38)'
check "Memphis has no volume on the desktop" 's.theme === "win98" && s.shown && !s.icons.includes("volume:sdb1")'
read -r x y <<<"$(desk where file:Projects)"
click "$x" "$y"
key Delete
check "Memphis asks before Delete" 's.alert && s.alert.title === "Confirm File Delete" && s.alert.accept === "&Yes"'
key n
check "No keeps the file" 's.alert === null && s.icons.includes("file:Projects") && !log.some((m) => m.type === "trash" && m.ids.includes("file:Projects"))'
desk emptyTrash >/dev/null
check "Empty Recycle Bin asks with No as the default" 's.alert && /3 items/.test(s.alert.text) && s.alert.defaultButton === "cancel"'
key Return
check "Enter takes the default: nothing emptied" 's.alert === null && !log.some((m) => m.type === "empty-trash")'

# A display change resubscribes with the new layout.
swaymsg -q output HEADLESS-1 scale 1.25
check "a display change resubscribes" 'log.some((m) => m.type === "subscribe" && m.screen.scale === 1.25 && m.screen.width === 2304)'
swaymsg -q output HEADLESS-1 scale 1.5
check "and back" 's.shown && s.usable.height === 1200 - 38'

# The provider goes away: no icons drawn as live, no input; then it returns.
provider_stop
check "provider down: no icons, no input" '!s.shown && !s.input && s.icons.length === 0 && s.alert === null'
SESSION_FIXTURE=stress provider_start node stress
check "provider back: live again, quietly" 's.shown && s.input && s.icons.includes("file:cascade-5")'

# A cascade: Tab reaches the covered icons; the focused one is on top.
desk select "file:cascade-0" >/dev/null
read -r x y <<<"$(desk where file:cascade-5)"
click 1700 900
desk select "file:cascade-0" >/dev/null
key Tab
check "Tab reaches a covered icon" 's.focus === "file:cascade-1"'
check "the focused icon is raised over the cascade" 'Object.keys(s.boxes).every((id) => id === "file:cascade-1" || s.boxes[id].z < s.boxes["file:cascade-1"].z)'
for _ in 1 2 3 4; do key Tab; done
check "Tab walks the whole cascade" 's.focus === "file:cascade-5"'
key Up
check "an arrow climbs the cascade" 's.focus === "file:cascade-4"'

grep -E "WARN|TypeError|ReferenceError|Error:" "$work/qs.log" | grep -v "propagateComposedEvents" > "$work/warnings.log" || true
if [ -s "$work/warnings.log" ]; then cat "$work/warnings.log"; bad "QML warnings"; fi
[ $fail = 0 ] && echo "DESKTOP_ICONS_BEHAVIOUR_PASSED" || { echo "DESKTOP_ICONS_BEHAVIOUR_FAILED"; exit 1; }

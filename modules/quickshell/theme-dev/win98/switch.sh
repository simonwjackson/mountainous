#!/usr/bin/env bash
# Platinum -> Win98 -> Platinum, ten times, through the real ThemeDesktop
# and theme-name file, in a private headless sway session; then a broken
# Win98 that must roll back. After each switch it asserts at the
# compositor:
#
#   - the reserved edge: sway's usable area (the workspace rectangle)
#     starts 28 px down for Platinum (its top bar) and ends 38 px up for
#     Win98 (its taskbar), with nothing reserved at the top;
#   - no chrome of the old theme left on screen: in a screenshot, the top
#     rows are bare desktop under Win98 and the bottom-left corner is bare
#     desktop under Platinum;
#
# and in the shell: one loaded Desktop slot, and no QML warning anywhere.
# checks.win98-desktop runs it; by hand:
#
#   modules/quickshell/theme-dev/win98/switch.sh <shell dir> [work dir]
#
# Needs sway, swaymsg, grim, qs, python3 on PATH and FONTCONFIG_FILE with
# W95FA Grid.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:-$(mktemp -d "${TMPDIR:-/tmp}/win98-switch.XXXXXX")}")
fail=0
pass=0

# shellcheck source=session.sh
. "$here/session.sh" "$shell_dir" "$work/run1" 2880x1800
trap session_stop EXIT
swaymsg -q output HEADLESS-1 bg '#204060' solid_color
sleep 1

name() { printf '%s\n' "$1" > "$XDG_STATE_HOME/mountainous/theme-name.new"; mv "$XDG_STATE_HOME/mountainous/theme-name.new" "$XDG_STATE_HOME/mountainous/theme-name"; }
loaded() { w98 current | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["loaded"], d["slots"])'; }
wait_loaded() { for _ in $(seq 60); do [ "$(loaded)" = "$1 1" ] && return 0; sleep 0.1; done; return 1; }
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
ok() { echo "PASS $1"; pass=$((pass + 1)); }
bad() { echo "FAIL $1"; fail=1; }
expect() { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1: got '$2', want '$3'"; fi; }

assert_theme() {
  local t=$1 round=$2
  wait_loaded "$t" || bad "round $round: $t did not load ($(loaded))"
  sleep 0.6
  read -r y height < <(rect)
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
assert_theme platinum 0
for round in 1 2 3 4 5 6 7 8 9 10; do
  name win98
  assert_theme win98 "$round"
  name platinum
  assert_theme platinum "$round"
done
if grep -E "WARN scene|TypeError|ReferenceError|Failed to load" "$work/run1/qs.log" >&2; then bad "QML warnings in 20 switches"; else ok "no QML warnings in 20 switches"; fi
grep -q "Desktop theme could not load" "$work/run1/commands.log" 2>/dev/null && bad "a notification during good switches" || ok "no failure notification"
session_stop

# A broken Win98 (a type that does not exist) must leave Platinum in place,
# write platinum back to theme-name and send one notification.
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
. "$here/session.sh" "$broken" "$work/run2" 2880x1800
swaymsg -q output HEADLESS-1 bg '#204060' solid_color
name platinum
sleep 1
assert_theme platinum broken-before
name win98
for _ in $(seq 60); do grep -q "Desktop theme could not load" "$work/run2/commands.log" 2>/dev/null && break; sleep 0.1; done
sleep 0.5
if grep -q "notify-send Desktop theme could not load win98:.*ThisWin98IsDeliberatelyBroken" "$work/run2/commands.log"; then ok "broken win98 sends a notification naming the error"; else bad "no notification ($(cat "$work/run2/commands.log" 2>/dev/null))"; fi
grep -q "desktop-theme set platinum" "$work/run2/commands.log" && ok "theme-name rolled back to platinum" || bad "no rollback"
expect "theme-name file" "$(cat "$XDG_STATE_HOME/mountainous/theme-name")" platinum
assert_theme platinum broken-after
session_stop
trap - EXIT

echo "$pass checks passed"
[ $fail = 0 ] && echo WIN98_SWITCH_PASSED || { echo WIN98_SWITCH_FAILED; exit 1; }

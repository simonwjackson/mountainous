#!/usr/bin/env bash
# Files' shell pieces in both themes, through the real Desktops over the
# harness fixtures: the apps' tray icons (StatusNotifierItems: Files with
# a lettermark, Ghostty with theme art, Krita hicolor-only so a
# lettermark), an app's menu drawn as a theme menu, Files in Start and the
# Apple menu, Show Desktop (the Memphis Quick Launch button, Platinum's
# Application menu), and the overflow at a narrow width.
#
# Shots, at scale 1.5 (device px), in <out>:
#   memphis-{light,dark}-*.png and platinum-{light,dark,extra}-*.png,
#   full screens (*-full) and crops of the bar, the menu or the window.
# It also asserts what a press does (from the harness log), that Show
# Desktop parks and brings back the page's windows, and no QML warnings.
#
#   capture-chrome.sh <shell dir> <work dir> <out dir>
#
# Needs the patched Quickshell as qs, the desktop-art package on
# XDG_DATA_DIRS, sway, grim and python3 with Pillow. checks.files-chrome-
# captures runs it.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(realpath "${1:?shell dir}")
work=$(realpath -m "${2:?work dir}")
out=$(realpath -m "${3:?out dir}")
mkdir -p "$out"
fail=0
ok() { echo "PASS $1"; }
bad() { echo "FAIL $1"; fail=1; }
expect() { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1: got '$2', want '$3'"; fi; }
contains() { case "$2" in *"$3"*) ok "$1";; *) bad "$1: '$3' not in '$2'";; esac; }

put() { printf '%s\n' "$2" > "$XDG_STATE_HOME/mountainous/$1.new"; mv "$XDG_STATE_HOME/mountainous/$1.new" "$XDG_STATE_HOME/mountainous/$1"; }
loaded() { for _ in $(seq 80); do w98 current | grep -q "\"loaded\":\"$1\"" && return 0; sleep 0.1; done; return 1; }
crop() {  # crop <in> <out> <x0> <y0> <x1> <y1>  (negative = from the far edge)
  python3 - "$@" <<'PY'
import sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src)
W, H = im.size
v = [int(a) for a in sys.argv[3:7]]
box = (v[0] % W if v[0] < 0 else v[0], v[1] % H if v[1] < 0 else v[1], W if v[2] == 0 else v[2] % W if v[2] < 0 else v[2], H if v[3] == 0 else v[3] % H if v[3] < 0 else v[3])
im.crop(box).save(dst)
PY
}
logsince() { w98 commands | tr '|' '\n' | tail -n "$1"; }

session_round() {  # session_round <tag> <WxH device px>
  local tag=$1 res=$2
  # shellcheck source=session.sh
  . "$here/session.sh" "$shell_dir" "$work/$tag" "$res"
  trap session_stop EXIT
  loaded win98 || bad "$tag: Win98 loaded"
}

# ---------------------------------------------------------------- full size
session_round full 2880x1800
w98 set tb-normal >/dev/null; sleep 1

for mode in light dark; do
  put theme-extra off; put theme-name win98; loaded win98
  w98 theme "$mode" >/dev/null
  w98 set tb-normal >/dev/null; sleep 1
  keys=$(w98 tray true); w98 files true >/dev/null; sleep 1.2
  expect "memphis $mode: tray keys (Passive hidden, registration order)" "$keys" '["sni:hensou-files","sni:ghostty","sni:org.kde.krita"]'
  p="$out/memphis-$mode"
  shot "$p-full.png"; crop "$p-full.png" "$p-tray.png" -1300 -84 0 0
  crop "$p-full.png" "$p-quick-launch.png" 0 -84 900 0
  # Presses: left activates, middle is secondary, a menu-only item opens its menu.
  w98 trayPress sni:hensou-files left >/dev/null; sleep 0.2
  contains "memphis $mode: left click activates" "$(logsince 3)" "tray sni:hensou-files activate"
  w98 trayPress sni:org.kde.krita middle >/dev/null; sleep 0.2
  contains "memphis $mode: middle click is secondary" "$(logsince 3)" "tray sni:org.kde.krita secondary"
  expect "memphis $mode: a menu-only item opens its menu" "$(w98 trayPress sni:ghostty left)" "sni"
  w98 closeAll >/dev/null; sleep 0.3
  expect "memphis $mode: right click opens the app's menu" "$(w98 trayPress sni:org.kde.krita right)" "sni"
  sleep 0.8; w98 cascade 1 >/dev/null; sleep 0.6
  shot "$p-sni-menu-full.png"; crop "$p-sni-menu-full.png" "$p-sni-menu.png" -1300 -700 0 0
  w98 closeAll >/dev/null; sleep 0.3
  w98 openMenu start >/dev/null; sleep 1
  contains "memphis $mode: Start has Files" "$(w98 item 0 Files)" " "
  shot "$p-start-full.png"; crop "$p-start-full.png" "$p-start-files.png" 0 -1200 900 0
  w98 closeAll >/dev/null; sleep 0.3
  # Show Desktop: the Quick Launch button pressed in, the windows' buttons raised.
  expect "memphis $mode: Show Desktop parks" "$(w98 showDesktop)" "show"
  sleep 0.8
  expect "memphis $mode: the desktop shows" "$(w98 desktopShown)" "true"
  shot "$p-shown-full.png"; crop "$p-shown-full.png" "$p-quick-launch-shown.png" 0 -84 900 0
  w98 taskbarMenu 1200 >/dev/null; sleep 0.6
  shot "$p-tbmenu-full.png"; crop "$p-tbmenu-full.png" "$p-taskbar-menu.png" 1500 -500 2500 0
  w98 closeAll >/dev/null; sleep 0.3
  expect "memphis $mode: Show Desktop brings them back" "$(w98 showDesktop)" "restore"
  expect "memphis $mode: covered again" "$(w98 desktopShown)" "false"
done

for mode in light dark extra; do
  if [ "$mode" = extra ]; then put theme-extra on; w98 theme dark >/dev/null; else put theme-extra off; w98 theme "$mode" >/dev/null; fi
  put theme-name platinum; loaded platinum || bad "platinum loaded"
  sleep 2
  w98 tray true >/dev/null; w98 files true >/dev/null; sleep 1.5
  p="$out/platinum-$mode"
  shot "$p-full.png"; crop "$p-full.png" "$p-tray.png" -1300 0 0 60
  w98 trayPress sni:hensou-files left >/dev/null; sleep 0.2
  contains "platinum $mode: left click activates" "$(logsince 3)" "tray sni:hensou-files activate"
  expect "platinum $mode: right click opens the app's menu" "$(w98 trayPress sni:org.kde.krita right)" "sni"
  sleep 0.8
  shot "$p-sni-menu-full.png"; crop "$p-sni-menu-full.png" "$p-sni-menu.png" -1300 0 0 600
  w98 closeAll >/dev/null; sleep 0.3
  w98 openMenu apple >/dev/null; sleep 0.8
  shot "$p-apple-full.png"; crop "$p-apple-full.png" "$p-apple-files.png" 0 0 900 900
  w98 closeAll >/dev/null; sleep 0.3
  w98 openMenu app >/dev/null; sleep 0.8
  shot "$p-app-full.png"; crop "$p-app-full.png" "$p-app-menu.png" -900 0 0 900
  w98 closeAll >/dev/null; sleep 0.3
  expect "platinum $mode: Show Desktop parks" "$(w98 showDesktop)" "show"
  sleep 0.5
  w98 openMenu app >/dev/null; sleep 0.8
  shot "$p-app-shown-full.png"; crop "$p-app-shown-full.png" "$p-app-menu-shown.png" -900 0 0 900
  w98 closeAll >/dev/null; sleep 0.3
  expect "platinum $mode: Show Desktop brings them back" "$(w98 showDesktop)" "restore"
done
put theme-extra off
cp "$work/full/qs.log" "$out/qs-full.log"
session_stop
trap - EXIT

# ---------------------------------------------------------------- narrow
# 600 x 700 logical: the app icons go into the tray chevron / » first,
# and each is still one choice away.
session_round narrow 900x1050
w98 theme light >/dev/null
w98 set tb-normal >/dev/null; sleep 1
w98 tray true >/dev/null; sleep 1.2
plan=$(w98 planOf)
contains "memphis narrow: an app icon in the chevron" "$plan" '"trayOut":["sni:'
shot "$out/memphis-narrow-full.png"
w98 openMenu more >/dev/null; sleep 0.8
shot "$out/memphis-narrow-more.png"
expect "memphis narrow: an app from the chevron opens its menu" "$(w98 trayChoose sni:org.kde.krita)" "sni"
sleep 0.8; shot "$out/memphis-narrow-sni-from-chevron.png"
w98 closeAll >/dev/null
put theme-name platinum; loaded platinum || bad "platinum loaded (narrow)"
sleep 2; w98 tray true >/dev/null; sleep 1.5
contains "platinum narrow: an app icon in »" "$(w98 planOf)" '"sni:'
shot "$out/platinum-narrow-full.png"
w98 openMenu more >/dev/null; sleep 0.8
shot "$out/platinum-narrow-more.png"
expect "platinum narrow: an app from » opens its menu" "$(w98 trayChoose sni:org.kde.krita)" "sni"
sleep 0.8; shot "$out/platinum-narrow-sni-from-more.png"
cp "$work/narrow/qs.log" "$out/qs-narrow.log"
session_stop
trap - EXIT

if grep -E 'WARN scene|TypeError|ReferenceError|is not defined|QML.*(Error|Warning)' "$out"/qs-*.log; then
  bad "QML warnings (above)"
fi
[ "$fail" = 0 ] && echo "FILES_CHROME_CAPTURES_PASSED"
exit "$fail"

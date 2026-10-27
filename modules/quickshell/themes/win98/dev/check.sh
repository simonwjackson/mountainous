#!/usr/bin/env bash
# The Win98 controls under a real Quickshell, headless, for nix flake check
# (checks.win98-theme) and by hand:
#
#   QUICKSHELL=qs LABWC=labwc modules/quickshell/themes/win98/dev/check.sh <shell dir>
#
# Loads Win98Gallery.qml with only Theme.qml, the flat Win98* controls and
# the theme's assets (so the theme imports nothing else from the shell), opens every page in both
# appearances, fails on any QML warning, then runs the Start menu's
# keyboard checks (keys.sh). No screenshots; dev/capture.sh takes those.
set -euo pipefail

shell_dir=$(realpath "${1:?shell dir (modules/quickshell)}")
here=$(cd "$(dirname "$0")" && pwd)
qs=${QUICKSHELL:-qs}
labwc=${LABWC:-labwc}

work=$(mktemp -d "${TMPDIR:-/tmp}/win98-check.XXXXXX")
export XDG_RUNTIME_DIR="$work/run" XDG_STATE_HOME="$work/state" XDG_CONFIG_HOME="$work/config"
export XDG_CACHE_HOME="$work/cache" XDG_DATA_HOME="$work/data" HOME="${HOME:-$work}"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME/mountainous" "$XDG_CONFIG_HOME/labwc" "$XDG_CACHE_HOME"
chmod 700 "$XDG_RUNTIME_DIR"
: > "$XDG_CONFIG_HOME/labwc/autostart"
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK
export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
export QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software

pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  wait 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

"$labwc" --config-dir "$XDG_CONFIG_HOME/labwc" >"$work/labwc.log" 2>&1 &
pids+=($!)
for _ in $(seq 100); do [ -S "$XDG_RUNTIME_DIR/wayland-0" ] && break; sleep 0.1; done
[ -S "$XDG_RUNTIME_DIR/wayland-0" ] || { cat "$work/labwc.log" >&2; exit 1; }
export WAYLAND_DISPLAY=wayland-0

stage="$work/shell"
mkdir -p "$stage/themes/win98"
# The control library only: the Desktop's own files (its windows and the
# Fleet views) import the shell's shared scripts, which the gallery does
# not stage. The theme's own policies (themes/win98/*.js) are its assets.
library() {
  for f in "$shell_dir"/Win98*.qml; do
    case "$(basename "$f")" in
      Win98Window.qml) ;;
      Win98Desktop.qml|Win98Taskbar.qml|Win98MenuHost.qml|Win98TipWindow.qml|Win98PickerView.qml|Win98Preview.qml|Win98LogOffDialog.qml|Win98OmniView.qml|Win98OpenDialog.qml|Win98*Window.qml) continue ;;
      Win98Fleet*.qml|Win98GlanceSpace.qml|Win98DisksAccessory.qml) continue ;;
    esac
    echo "$f"
  done
}
cp "$shell_dir/Theme.qml" $(library) "$here/Win98Gallery.qml" "$stage/"
cp -r "$shell_dir/themes/win98/icons" "$stage/themes/win98/icons"
for f in "$shell_dir"/themes/win98/*.js; do case "$f" in *.test.js) ;; *) cp "$f" "$stage/themes/win98/" ;; esac; done
chmod -R u+w "$stage"
cat > "$stage/shell.qml" <<'QML'
import Quickshell

ShellRoot {
    Win98Gallery {}
}
QML
printf 'light\n' > "$XDG_STATE_HOME/mountainous/theme"

"$qs" -p "$stage/shell.qml" --no-color >"$work/qs.log" 2>&1 &
pids+=($!)
ipc() { "$qs" -p "$stage/shell.qml" ipc call win98gallery "$@" 2>/dev/null; }
for _ in $(seq 100); do ipc ready >/dev/null && break; sleep 0.2; done
ipc ready >/dev/null || { cat "$work/qs.log" >&2; echo "WIN98_GALLERY_DID_NOT_START" >&2; exit 1; }

for a in light dark; do
  printf '%s\n' "$a" > "$XDG_STATE_HOME/mountainous/theme"
  sleep 0.4
  for p in text controls fields frames menus lists icons stress scenes; do
    ipc page "$p" >/dev/null
    sleep 0.3
  done
  echo "pages ok ($a): $(ipc ready)"
done

fail=0
. "$here/keys.sh"

# Font fallback notes are not defects; anything else from QML is.
if grep -E "WARN|ERROR" "$work/qs.log" | grep -vE "FontLoader|Cannot load font|libEGL|MESA" | grep -q .; then
  grep -E "WARN|ERROR" "$work/qs.log" | grep -vE "FontLoader|Cannot load font|libEGL|MESA" >&2
  echo "WIN98_QML_WARNINGS" >&2
  fail=1
fi
[ $fail = 0 ] || { echo "WIN98_CHECK_FAILED" >&2; exit 1; }
echo "WIN98_CHECK_PASSED"

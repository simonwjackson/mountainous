#!/usr/bin/env bash
# The Memphis controls under a real Quickshell, headless, for nix flake check
# (checks.memphis-theme) and by hand:
#
#   QUICKSHELL=qs LABWC=labwc modules/quickshell/themes/memphis/dev/check.sh <shell dir>
#
# Loads MemphisGallery.qml with Theme.qml, the inert SoundEvents bus, the pure
# app-icon.js, Memphis* controls and the theme's assets (so the theme imports
# nothing else from the shell), opens every page in both
# appearances, fails on any QML warning, then runs the Start menu's
# keyboard checks (keys.sh). No screenshots; dev/capture.sh takes those.
set -euo pipefail

shell_dir=$(realpath "${1:?shell dir (modules/quickshell)}")
here=$(cd "$(dirname "$0")" && pwd)
qs=${QUICKSHELL:-qs}
labwc=${LABWC:-labwc}

work=$(mktemp -d "${TMPDIR:-/tmp}/memphis-check.XXXXXX")
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
mkdir -p "$stage/themes/memphis"
# The control library only: the Desktop's own files (its windows and the
# Fleet views) import the shell's shared scripts, which the gallery does
# not stage. The theme's own policies (themes/memphis/*.js) are its assets.
library() {
  for f in "$shell_dir"/Memphis*.qml; do
    case "$(basename "$f")" in
      MemphisWindow.qml) ;;
      MemphisDesktop.qml|MemphisTaskbar.qml|MemphisMenuHost.qml|MemphisTipWindow.qml|MemphisPickerView.qml|MemphisPreview.qml|MemphisLogOffDialog.qml|MemphisOmniView.qml|MemphisOpenDialog.qml|Memphis*Window.qml) continue ;;
      MemphisFleet*.qml|MemphisGlanceSpace.qml|MemphisDisksAccessory.qml|MemphisMotionLayer.qml) continue ;;
    esac
    echo "$f"
  done
}
cp "$shell_dir/Theme.qml" "$shell_dir/SoundEvents.qml" "$shell_dir/app-icon.js" "$shell_dir/hensou-host.js" $(library) "$here/MemphisGallery.qml" "$stage/"
cp -r "$shell_dir/themes/memphis/icons" "$stage/themes/memphis/icons"
for f in "$shell_dir"/themes/memphis/*.js; do case "$f" in *.test.js) ;; *) cp "$f" "$stage/themes/memphis/" ;; esac; done
chmod -R u+w "$stage"
cat > "$stage/shell.qml" <<'QML'
import Quickshell

ShellRoot {
    MemphisGallery {}
}
QML
printf 'light\n' > "$XDG_STATE_HOME/mountainous/theme"

"$qs" -p "$stage/shell.qml" --no-color >"$work/qs.log" 2>&1 &
pids+=($!)
ipc() { "$qs" -p "$stage/shell.qml" ipc call memphisgallery "$@" 2>/dev/null; }
for _ in $(seq 100); do ipc ready >/dev/null && break; sleep 0.2; done
ipc ready >/dev/null || { cat "$work/qs.log" >&2; echo "MEMPHIS_GALLERY_DID_NOT_START" >&2; exit 1; }

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
. "$here/access.sh"

# Font fallback notes are not defects; anything else from QML is.
if grep -E "WARN|ERROR" "$work/qs.log" | grep -vE "FontLoader|Cannot load font|libEGL|MESA" | grep -q .; then
  grep -E "WARN|ERROR" "$work/qs.log" | grep -vE "FontLoader|Cannot load font|libEGL|MESA" >&2
  echo "MEMPHIS_QML_WARNINGS" >&2
  fail=1
fi
[ $fail = 0 ] || { echo "MEMPHIS_CHECK_FAILED" >&2; exit 1; }
echo "MEMPHIS_CHECK_PASSED"

#!/usr/bin/env bash
# Screenshots of Win98Gallery.qml in an isolated, headless sway session.
# Development only; nothing installs this.
#
#   modules/quickshell/themes/win98/dev/capture.sh [outdir] [page ...]
#
# The output matches Myoko: a 2880x1800 panel at scale 1.5, so Quickshell
# lays out at 1920x1200 and 1 u = 2 physical px. Each gallery page is shot
# in both appearances (Theme.dark false and true) as
# <outdir>/<page>-light.png and <page>-grey.png, in physical pixels.
#
# Its own XDG_RUNTIME_DIR, state, config and cache dirs; the running
# desktop and its Quickshell are never touched. The gallery loads W95FA
# Grid from $WIN98_FONT (default: the approved mock's copy).
#
# Tools come from this flake's pinned packages. Run it from the repo.
set -euo pipefail

if [ -z "${WIN98_DEV_SHELL:-}" ]; then
  repo=$(git rev-parse --show-toplevel)
  export WIN98_DEV_SHELL=1
  pkg() { nix build --no-link --print-out-paths "$repo#nixosConfigurations.myoko.pkgs.$1"; }
  PATH="$(pkg sway)/bin:$(pkg grim)/bin:$(pkg quickshell)/bin:$PATH"
  export PATH
  exec bash "$0" "$@"
fi

here=$(cd "$(dirname "$0")" && pwd)
theme_dir=$(cd "$here/.." && pwd)
shell_dir=$(cd "$theme_dir/../.." && pwd)
out=$(realpath -m "${1:-/tmp/win98-components}")
shift || true
pages=("$@")
[ ${#pages[@]} -gt 0 ] || pages=(text controls fields frames menus lists icons stress scenes)
mkdir -p "$out"

work=$(mktemp -d /tmp/win98-gallery.XXXXXX)
export XDG_RUNTIME_DIR="$work/run" XDG_STATE_HOME="$work/state" XDG_CONFIG_HOME="$work/config"
export XDG_CACHE_HOME="$work/cache" XDG_DATA_HOME="$work/data"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME/mountainous" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK
export WIN98_FONT=${WIN98_FONT:-/tmp/win98-mock/fonts/W95FAGrid.ttf}
test -f "$WIN98_FONT" || { echo "no font at $WIN98_FONT" >&2; exit 1; }

cat > "$work/sway.conf" <<EOF
output HEADLESS-1 resolution ${WIN98_RES:-2880x1800} scale 1.5 bg #202830 solid_color
default_border none
EOF

pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  wait 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
  sway -c "$work/sway.conf" >"$work/sway.log" 2>&1 &
pids+=($!)
sock=""
for _ in $(seq 50); do
  sock=$(ls "$XDG_RUNTIME_DIR" 2>/dev/null | grep -E '^wayland-[0-9]+$' | head -1 || true)
  [ -n "$sock" ] && break
  sleep 0.1
done
export WAYLAND_DISPLAY="$sock"

# The shell root, as the theme loader will see it: Theme.qml and the flat
# Win98*.qml files at the top, the theme's assets under themes/win98. Only
# Theme.qml is staged beside them, which also proves the theme imports
# nothing else from the shell. A stub shell.qml loads only the gallery.
stage="$work/shell"
mkdir -p "$stage/themes/win98"
ln -s "$shell_dir/Theme.qml" "$stage/Theme.qml"
for f in "$shell_dir"/Win98*.qml; do
  case "$(basename "$f")" in
    Win98Window.qml) ;;
    # The Desktop's own files import the shell's shared scripts.
    Win98Desktop.qml|Win98Taskbar.qml|Win98MenuHost.qml|Win98TipWindow.qml|Win98PickerView.qml|Win98Preview.qml|Win98LogOffDialog.qml|Win98*Window.qml) continue ;;
  esac
  ln -s "$f" "$stage/$(basename "$f")"
done
ln -s "$here/Win98Gallery.qml" "$stage/Win98Gallery.qml"
ln -s "$theme_dir/icons" "$stage/themes/win98/icons"
cat > "$stage/shell.qml" <<'EOF'
import Quickshell

ShellRoot {
    Win98Gallery {}
}
EOF

theme() { printf '%s\n' "$1" > "$XDG_STATE_HOME/mountainous/theme"; }
theme light

QT_QPA_PLATFORM=wayland QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough \
  qs -p "$stage/shell.qml" >"$work/qs.log" 2>&1 &
pids+=($!)
ipc() { qs -p "$stage/shell.qml" ipc call win98gallery "$@" 2>/dev/null; }
for _ in $(seq 50); do ipc ready >/dev/null && break; sleep 0.2; done
ipc ready >/dev/null || { cat "$work/qs.log" >&2; exit 1; }
sleep 1

for a in light grey; do
  theme "$([ $a = grey ] && echo dark || echo light)"
  sleep 0.6
  for p in "${pages[@]}"; do
    ipc page "$p" >/dev/null
    sleep 0.8
    grim "$out/$p-$a.png"
    echo "$out/$p-$a.png  [$(ipc ready)]"
  done
done


# ---- the Start menu's keyboard and the roll-out (dev/keys.sh)
fail=0
. "$here/keys.sh"
grep -E "WARN|ERROR|TypeError|ReferenceError" "$work/qs.log" > "$out/qs-warnings.log" || true
cp "$work/qs.log" "$out/qs.log"
echo "warnings: $(wc -l < "$out/qs-warnings.log") (see $out/qs-warnings.log)"
[ $fail = 0 ] && echo "KEYS_PASSED" || { echo "KEYS_FAILED"; exit 1; }

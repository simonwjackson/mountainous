#!/usr/bin/env bash
# Headless renders of every desktop appearance: the 22 Memphis appearances
# and Platinum's Light, Dark grey and Drawing Board, each with its desktop,
# a window and a menu, plus the registry thumbnails cut from them, and the
# picker ladder. Development only; nothing installs this. It runs the real
# shell through the Memphis harness (theme-dev/memphis/session.sh): sway's
# headless backend, private directories, no DRM output.
#
#   modules/quickshell/theme-dev/schemes/render.sh <outdir> [part ...]
#
# part: memphis, platinum, ladder (default: all three).
# Session directories stay short: Quickshell's IPC socket path must fit
# in 108 bytes.
# Writes <outdir>/<theme>/<appearance>/{window,menu,sound}.png (2880x1800,
# 1920x1200 logical at 1.5), <outdir>/thumbnails/<theme>/<appearance>.png
# (360x225, cut as the registered ones were: Memphis the bottom-right of
# the Sound window state, Platinum the bar and its Sound menu) and
# <outdir>/ladder/<picker>-<W>x<H>[-list].png (logical sizes).
#
# Env:
#   HENSOU_QML      the kit's qml directory (the parent of Hensou/); required.
#   RENDER_OVERLAY  a directory copied over the staged shell first, for
#                   files another branch owns that have not landed yet.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_src=$(cd "$here/../.." && pwd)
repo=$(cd "$shell_src/../.." && pwd)
out=$(realpath -m "${1:?outdir}")
shift
parts=${*:-memphis platinum ladder}
: "${HENSOU_QML:?set HENSOU_QML to the kit qml directory}"
mkdir -p "$out"

if [ -z "${MEMPHIS_DEV_TOOLS:-}" ]; then
  export MEMPHIS_DEV_TOOLS=1
  pkg() { nix build --option builders '' --max-jobs 1 --cores 4 --no-link --print-out-paths "$repo#nixosConfigurations.myoko.pkgs.$1"; }
  PATH="$(pkg sway)/bin:$(pkg swaybg)/bin:$(pkg grim)/bin:$(pkg quickshell)/bin:$(pkg wtype)/bin:$(pkg imagemagick)/bin:$(pkg nodejs)/bin:$PATH"
  font=$(nix build --option builders '' --max-jobs 1 --cores 4 --no-link --print-out-paths "$repo#packages.x86_64-linux.w95fa-grid")
  chicago=$(nix build --option builders '' --max-jobs 1 --cores 4 --no-link --print-out-paths "$repo#packages.x86_64-linux.chicagoflf")
  dejavu=$(pkg dejavu_fonts)
  QML2_IMPORT_PATH="$HENSOU_QML:$(pkg qt6.qtwebsockets)/lib/qt-6/qml:$(pkg qt6.qtmultimedia)/lib/qt-6/qml"
  export QML2_IMPORT_PATH
  export PATH
  # Mesa's llvmpipe, as checks.memphis-desktop renders (Qt's own software
  # renderer draws 1.5-scale lines unevenly).
  mesa=$(pkg mesa)
  export __EGL_VENDOR_LIBRARY_DIRS="$mesa/share/glvnd/egl_vendor.d" LIBGL_DRIVERS_PATH="$mesa/lib/dri"
  cfg="$out/fonts.conf"
  printf '<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig><dir>%s/share/fonts</dir><dir>%s/share/fonts</dir><dir>%s/share/fonts</dir><cachedir>%s/fontcache</cachedir></fontconfig>\n' \
    "$font" "$chicago" "$dejavu" "$out" > "$cfg"
  export FONTCONFIG_FILE="$cfg"
  bash "$shell_src/notification-schema-js.sh" "$repo/packages/notify-sync/schema/ui-socket.v1.json" > "$out/notification-schema.js"
  export SESSION_SCHEMA="$out/notification-schema.js"
fi

# The shell as staged: the tree, then the overlay.
shell_dir="$out/shell-src"
rm -rf "$shell_dir"
mkdir -p "$shell_dir"
cp -r "$shell_src"/. "$shell_dir"/
[ -n "${RENDER_OVERLAY:-}" ] && cp -r "$RENDER_OVERLAY"/. "$shell_dir"/
chmod -R u+w "$shell_dir"

# Appearance IDs, from the kit itself.
ids() {
  node -e '
const src = require("fs").readFileSync(process.argv[1], "utf8");
const block = src.slice(src.indexOf("readonly property var appearances: ["), src.indexOf("]", src.indexOf("readonly property var appearances: [")));
for (const m of block.matchAll(/id: "([a-z0-9-]+)"/g)) console.log(m[1]);' "$HENSOU_QML/Hensou/$1"
}

# A desktop: a plain colour, or a pattern tile (8 x 8 cells at 3 device px,
# as DesktopPattern draws Platinum's).
desktop_bg() {
  case "$1" in
    \#*) swaymsg -q output HEADLESS-1 bg "$1" solid_color ;;
    *.svg)
      local tile
      tile="$out/tiles/$(basename "$(dirname "$(dirname "$1")")")-$(basename "$1" .svg).png"
      mkdir -p "$out/tiles"
      magick -background none "$1" -filter point -resize "$((8 * ${2:-3}))x$((8 * ${2:-3}))" "$tile"
      swaymsg -q output HEADLESS-1 bg "$tile" tile ;;
  esac
}
settle() { sleep "${1:-0.8}"; for _ in $(seq 30); do memphis current | grep -q '"settled":true' && break; sleep 0.1; done; sleep 0.4; }
: > "$out/warnings.log"
finish() {
  # session_work is set by session.sh, which each part sources.
  # shellcheck disable=SC2154
  session_stop
  # shellcheck disable=SC2154
  grep -E "WARN scene|TypeError|ReferenceError|Error:" "$session_work/qs.log" >> "$out/warnings.log" || true
}

memphis() {
  # shellcheck source=/dev/null
  SESSION_THEME=memphis . "$here/../memphis/session.sh" "$shell_dir" "$out/session-memphis" 2880x1800
  sleep 1.5
  for id in $(ids MemphisTokens.qml); do
    local dir="$out/memphis/$id"; mkdir -p "$dir"
    echo "memphis $id: $(memphis appearance "$id")"
    case "$id" in
      standard) desktop_bg "$shell_dir/themes/memphis/patterns/light.svg" 2 ;;
      dark-grey) desktop_bg "$shell_dir/themes/memphis/patterns/dark.svg" 2 ;;
      *) desktop_bg "$(memphis desktopColour)" ;;
    esac
    # A window: System Properties over an inactive app window.
    memphis closeAll >/dev/null; memphis set tb-normal >/dev/null; settle
    memphis app '{"rect":[220,160,860,520],"title":"Untitled - Notepad","active":false}' >/dev/null
    memphis about >/dev/null; sleep 1.0
    shot "$dir/window.png"
    # A menu: Start > Programs over the active app window.
    memphis closeAll >/dev/null; memphis set s-programs >/dev/null; settle
    memphis app '{"rect":[220,160,860,520],"title":"Untitled - Notepad","active":true}' >/dev/null; sleep 0.6
    shot "$dir/menu.png"
    # The Sound window: the registry thumbnail's source.
    memphis app "" >/dev/null; memphis closeAll >/dev/null; memphis set m-sound >/dev/null; settle
    shot "$dir/sound.png"
    mkdir -p "$out/thumbnails/memphis"
    magick "$dir/sound.png" -crop 1080x675+1800+1125 +repage -resize 360x225 "$out/thumbnails/memphis/$id.png"
  done
  finish
}

platinum() {
  # shellcheck source=/dev/null
  SESSION_THEME=platinum . "$here/../memphis/session.sh" "$shell_dir" "$out/session-platinum" 2880x1800
  sleep 1.5
  for id in $(ids PlatinumTokens.qml); do
    local dir="$out/platinum/$id"; mkdir -p "$dir"
    echo "platinum $id: $(memphis appearance "$id")"
    case "$id" in
      light) desktop_bg "$shell_dir/themes/platinum/patterns/light.svg" ;;
      dark-grey) desktop_bg "$shell_dir/themes/platinum/patterns/dark.svg" ;;
      *) desktop_bg "$shell_dir/themes/platinum/patterns/$id.svg" ;;
    esac
    memphis closeAll >/dev/null; sleep 0.4
    memphis about >/dev/null; sleep 1.0
    shot "$dir/window.png"
    memphis closeAll >/dev/null; sleep 0.4
    memphis openMenu vol >/dev/null; sleep 1.0
    shot "$dir/menu.png"
    mkdir -p "$out/thumbnails/platinum"
    magick "$dir/menu.png" -crop "${PLATINUM_CROP:-1080x675+1800+0}" +repage -resize 360x225 "$out/thumbnails/platinum/$id.png"
    memphis openMenu clock >/dev/null; sleep 1.0
    shot "$dir/clock-menu.png"
    memphis closeAll >/dev/null
  done
  finish
}

# The pickers at the documented logical sizes, at scale 1.5.
ladder() {
  local sizes="1920x1200 960x600 240x800 1200x180 160x150 160x80 80x800"
  mkdir -p "$out/ladder"
  for theme in memphis platinum; do
    for size in $sizes; do
      local w=${size%x*} h=${size#*x}
      # shellcheck source=/dev/null
      SESSION_THEME=$theme . "$here/../memphis/session.sh" "$shell_dir" "$out/l-${theme:0:1}$size" "$((w * 3 / 2))x$((h * 3 / 2))"
      sleep 1.5
      if [ "$theme" = memphis ]; then
        memphis appearance standard >/dev/null; desktop_bg '#008080'
        memphis openPicker >/dev/null; sleep 1.2
        memphis pickerShow '{"theme":"memphis","scheme":"high-contrast-1"}' >/dev/null; sleep 0.6
        shot "$out/ladder/memphis-$size.png"
        memphis pickerShow '{"theme":"memphis","scheme":"rainy-day","drop":"scheme"}' >/dev/null; sleep 0.6
        shot "$out/ladder/memphis-$size-list.png"
        memphis geometry > "$out/ladder/memphis-$size.json" || true
      else
        memphis appearance drawing-board >/dev/null; desktop_bg "$shell_dir/themes/platinum/patterns/drawing-board.svg"
        memphis openPicker >/dev/null; sleep 1.2
        shot "$out/ladder/platinum-$size.png"
      fi
      finish
    done
  done
}

for part in $parts; do "$part"; done
echo "warnings: $(wc -l < "$out/warnings.log") ($out/warnings.log)"

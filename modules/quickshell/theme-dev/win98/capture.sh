#!/usr/bin/env bash
# Screenshots of the real Win98 Desktop in every state of the approved mock's
# catalogue (states.js), in both appearances, headless at Myoko's 2880x1800
# panel and scale 1.5 (width states at their own width). Development only;
# nothing installs this.
#
#   modules/quickshell/theme-dev/win98/capture.sh <outdir> [state ...]
#
# Writes <outdir>/<light|grey>/<state>.png (physical px) and a log of QML
# warnings. Tools come from this flake's pinned Myoko packages; the font is
# the packaged W95FA Grid. See session.sh for the isolation.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(cd "$here/../.." && pwd)
repo=$(cd "$shell_dir/../.." && pwd)
out=$(realpath -m "${1:?outdir}")
shift
mkdir -p "$out/light" "$out/grey"

if [ -z "${WIN98_DEV_TOOLS:-}" ]; then
  export WIN98_DEV_TOOLS=1
  pkg() { nix build --option builders '' --no-link --print-out-paths "$repo#nixosConfigurations.myoko.pkgs.$1"; }
  PATH="$(pkg sway)/bin:$(pkg grim)/bin:$(pkg quickshell)/bin:$(pkg wtype)/bin:$(pkg imagemagick)/bin:$PATH"
  font=$(nix build --option builders '' --no-link --print-out-paths "$repo#packages.x86_64-linux.w95fa-grid")
  dejavu=$(pkg dejavu_fonts)
  export QML2_IMPORT_PATH="$(pkg qt6.qtwebsockets)/lib/qt-6/qml"
  export PATH
  cfg="$out/fonts.conf"
  printf '<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig><dir>%s/share/fonts</dir><dir>%s/share/fonts</dir><cachedir>%s/fontcache</cachedir></fontconfig>\n' \
    "$font" "$dejavu" "$out" > "$cfg"
  export FONTCONFIG_FILE="$cfg"
  bash "$shell_dir/notification-schema-js.sh" "$repo/packages/notify-sync/schema/ui-socket.v1.json" > "$out/notification-schema.js"
  export SESSION_SCHEMA="$out/notification-schema.js"
fi

# Every state, with its width (logical px), from the catalogue itself.
list=$(node -e '
const fs = require("fs"), vm = require("vm"); const c = {}; vm.createContext(c);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8").replace(/^\.pragma library$/m, ""), c);
const want = process.argv.slice(2);
for (const id of c.stateIds()) { const s = c.stateById(id); if (!want.length || want.includes(id)) console.log(id + " " + (s.p.w || 1920)); }
' "$here/states.js" "$@")

: > "$out/warnings.log"
for width in $(echo "$list" | awk '{print $2}' | sort -un); do
  ids=$(echo "$list" | awk -v w="$width" '$2 == w {print $1}')
  # shellcheck source=session.sh
  . "$here/session.sh" "$shell_dir" "$out/session-$width" "$((width * 3 / 2))x1800"
  sleep 1.5
  for a in light grey; do
    w98 theme "$([ $a = grey ] && echo dark || echo light)" >/dev/null
    # The desktop behind the chrome: Win98's own colour for the scheme.
    swaymsg -q output HEADLESS-1 bg "$([ $a = grey ] && echo '#000000' || echo '#008080')" solid_color
    for id in $ids; do
      w98 set "$id" >/dev/null
      sleep 0.9
      shot "$out/$a/$id.png"
      echo "$a/$id $(w98 current | head -c 160)"
    done
  done
  session_stop
  grep -E "WARN scene|TypeError|ReferenceError|Error:" "$out/session-$width/qs.log" >> "$out/warnings.log" || true
done
# The registry's thumbnails: the bottom-right third of the Sound window
# state, as the Platinum ones are cut from its bar and Sound menu.
if [ -f "$out/light/m-sound.png" ] && [ -f "$out/grey/m-sound.png" ] && command -v magick >/dev/null; then
  for a in light grey; do
    magick "$out/$a/m-sound.png" -crop 1080x675+1800+1125 +repage -resize 360x225 "$out/thumbnail-$a.png"
  done
fi
echo "warnings: $(wc -l < "$out/warnings.log") ($out/warnings.log)"

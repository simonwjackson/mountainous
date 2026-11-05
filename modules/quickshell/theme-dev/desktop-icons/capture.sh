#!/usr/bin/env bash
# Screenshots of the desktop icon layer in both themes, every appearance
# (Platinum light, dark, extra dark; Memphis light, dark), headless at
# Myoko's 2880x1800 panel and scale 1.5. Development only; nothing
# installs this.
#
#   DESKTOP_STUB=/path/to/hensou-desktop-stub \
#     modules/quickshell/theme-dev/desktop-icons/capture.sh <outdir>
#
# Writes <outdir>/<appearance>/<state>.png (physical px) and a log of QML
# warnings. States: icons (a selection), under-window, icon-menu,
# desktop-menu, trash-menu, trash-confirm (Memphis asks; Platinum moves at
# once, so it shows the permanent warning), permanent, empty-trash,
# eject-busy, rename, then with provider.js: stress (long and unbreakable
# names, an unavailable alias, a hicolor-only launcher, a cascade with its
# last icon selected and raised) and down (the provider gone: no icons).
# Tools come from this flake's pinned Myoko packages.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell_dir=$(cd "$here/../.." && pwd)
repo=$(cd "$shell_dir/../.." && pwd)
out=$(realpath -m "${1:?outdir}")
mkdir -p "$out"

if [ -z "${DESKTOP_DEV_TOOLS:-}" ]; then
  export DESKTOP_DEV_TOOLS=1
  pkg() { nix build --option builders '' --no-link --print-out-paths "$repo#nixosConfigurations.myoko.pkgs.$1"; }
  flake() { nix build --option builders '' --no-link --print-out-paths "$repo#packages.x86_64-linux.$1"; }
  PATH="$(pkg sway)/bin:$(pkg grim)/bin:$(flake quickshell-mountainous)/bin:$(pkg nodejs)/bin:$(pkg imagemagick)/bin:$PATH"
  export PATH
  w95=$(flake w95fa-grid); chicago=$(flake chicagoflf); dejavu=$(pkg dejavu_fonts)
  art=$(flake desktop-art)
  export XDG_DATA_DIRS="$art/share:$(pkg hicolor-icon-theme)/share"
  hensou_qml=$(nix eval --raw "$repo#nixosConfigurations.myoko.config.systemd.user.services.quickshell.environment.QML2_IMPORT_PATH")
  export QML2_IMPORT_PATH="$hensou_qml:$(pkg qt6.qtmultimedia)/lib/qt-6/qml:$(pkg qt6.qtwebsockets)/lib/qt-6/qml"
  cfg="$out/fonts.conf"
  printf '<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig><dir>%s/share/fonts</dir><dir>%s/share/fonts</dir><dir>%s/share/fonts</dir><cachedir>%s/fontcache</cachedir></fontconfig>\n' \
    "$w95" "$chicago" "$dejavu" "$out" > "$cfg"
  export FONTCONFIG_FILE="$cfg"
fi

# shellcheck source=session.sh
. "$here/session.sh" "$shell_dir" "$out/session" "${DESKTOP_RES:-2880x1800}"
trap session_stop EXIT
desk_wait live || { cat "$out/session/qs.log" >&2; echo "no live session" >&2; exit 1; }

snap() { sleep 0.7; shot "$out/$1/$2.png"; echo "$1/$2 $(desk current | head -c 200)"; }
settle() { sleep 0.4; desk closeAll >/dev/null; sleep 0.3; }

appearances="platinum:light:off:platinum-light platinum:dark:off:platinum-dark platinum:dark:on:platinum-extra win98:light:off:memphis-light win98:dark:off:memphis-dark"
for a in $appearances; do
  IFS=: read -r name mode extra label <<<"$a"
  mkdir -p "$out/$label"
  theme "$name" "$mode" "$extra"
  sleep 1.2
  desk_wait live
  trash=trash; volume=volume:sdb1
  desk select "file:notes.txt" >/dev/null; snap "$label" icons
  desk window 60 150 900 520 >/dev/null; snap "$label" under-window; desk window 0 0 0 0 >/dev/null
  desk menu "file:notes.txt" >/dev/null; snap "$label" icon-menu; settle
  desk menu "" >/dev/null; snap "$label" desktop-menu; settle
  desk menu "$trash" >/dev/null; snap "$label" trash-menu; settle
  if [ "$name" = win98 ]; then
    desk trash "file:notes.txt" >/dev/null; snap "$label" trash-confirm; settle
  fi
  desk permanent "file:Projects" "USB has no Trash." >/dev/null; snap "$label" permanent; settle
  desk emptyTrash >/dev/null; snap "$label" empty-trash; settle
  if [ "$name" = platinum ]; then
    desk eject "$volume" >/dev/null; snap "$label" eject-busy; settle
  else
    desk eject "volume:sdb1" >/dev/null; snap "$label" eject-busy; settle
  fi
  desk rename "file:Projects" >/dev/null; snap "$label" rename; settle
done

# The stress set and the provider going away, with provider.js.
provider_stop
desk_wait down || true
for a in $appearances; do
  IFS=: read -r name mode extra label <<<"$a"
  theme "$name" "$mode" "$extra"
  sleep 1
  shot "$out/$label/down.png"
done
provider_start node stress
for a in $appearances; do
  IFS=: read -r name mode extra label <<<"$a"
  theme "$name" "$mode" "$extra"
  sleep 1.2
  desk_wait live || true
  desk select "file:word,file:cascade-1" >/dev/null
  snap "$label" stress
done

session_stop
grep -E "WARN scene|WARN: qs:|TypeError|ReferenceError|Binding loop" "$out/session/qs.log" > "$out/warnings.log" || true
echo "warnings: $(wc -l < "$out/warnings.log") ($out/warnings.log)"

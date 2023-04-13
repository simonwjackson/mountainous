#! /usr/bin/env nix-shell
#! nix-shell -i bash -p python38Packages.pywal

HOUR=$(date +%H)
WALLPAPER_DIR="$HOME/downloads"

if [ "${HOUR}" -ge 6 ] && [ "${HOUR}" -lt 12 ]; then
  WALLPAPER="$WALLPAPER_DIR/morning.jpg"
elif [ "${HOUR}" -ge 12 ] && [ "${HOUR}" -lt 18 ]; then
  WALLPAPER="$WALLPAPER_DIR/afternoon.png"
elif [ "${HOUR}" -ge 18 ] && [ "${HOUR}" -lt 22 ]; then
  WALLPAPER="${WALLPAPER_DIR}/evening.png"
else
  WALLPAPER="${WALLPAPER_DIR}/night.png"
fi

wal -i "${WALLPAPER}" -t

# feh --bg-scale "${WALLPAPER}"

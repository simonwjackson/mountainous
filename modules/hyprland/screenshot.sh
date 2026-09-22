set -euo pipefail

case "${1:-}" in
  screen)
    capture=(grim -)
    ;;
  window)
    if ! geometry=$(hyprctl --instance 0 -j activewindow | jq -er '
      select(.address != null and .address != "" and .address != "0x")
      | select(.at != null and .size != null)
      | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    '); then
      echo "mountainous-screenshot: no active window" >&2
      exit 1
    fi
    capture=(grim -g "$geometry" -)
    ;;
  *)
    echo "usage: mountainous-screenshot screen|window" >&2
    exit 2
    ;;
esac

output_dir="$HOME/Pictures/Screenshots"
mkdir -p "$output_dir"
output="$output_dir/$(date +%Y-%m-%d_%H-%M-%S_%N).png"

"${capture[@]}" | satty \
  --filename - \
  --output-filename "$output" \
  --copy-command wl-copy \
  --save-after-copy \
  --early-exit all \
  --initial-tool brush \
  --fullscreen current-screen \
  --no-window-decoration \
  --title Screenshot \
  --app-id io.mountainous.Screenshot

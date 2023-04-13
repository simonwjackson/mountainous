#! /usr/bin/env nix-shell
#! nix-shell -i bash -p youtube-dl mpv yt-dlp

YOUTUBE_URL="https://www.youtube.com/watch?v=BUuBCCU3dKQ"
CACHE_DIR="$HOME/.cache/youtube_wallpaper"
MPV_CONFIG="$HOME/mpv-wallpaper.conf"

mkdir -p "$CACHE_DIR"
VIDEO_PATH="$CACHE_DIR/video.mp4"

# Download the YouTube video using yt-dlp
if [ ! -f "$VIDEO_PATH" ]; then
  yt-dlp -f best -o "$VIDEO_PATH" "$YOUTUBE_URL"
fi

# Kill any existing instances of mpv
killall mpv 2>/dev/null

# Get the root window ID
ROOT_WINDOW_ID=$(xwininfo -root | grep 'Window id:' | awk '{print $4}')

# Play the video in a loop as wallpaper using mpv with inline configurations
mpv \
  --no-audio \
  --no-osc \
  --no-osd-bar \
  --loop-file \
  --ontop \
  --no-border \
  --geometry=100%x100% \
  --wid="$ROOT_WINDOW_ID" \
  --panscan=1.0 \
  --no-input-default-bindings \
  --no-input-cursor \
  --cursor-autohide-fs-only \
  --cursor-autohide=1000 \
  --no-keepaspect-window \
  --no-window-dragging \
  "$VIDEO_PATH"

# Kill any existing instances of xwinwrap
# killall xwinwrap 2>/dev/null

# Play the video in a loop as wallpaper using xwinwrap and mpv
# xwinwrap -ov -fs -- mpv -wid WID --no-audio --no-osc --no-osd-bar --loop-file --really-quiet --panscan=1.0 --no-input-default-bindings --no-input-cursor --no-input-ipc-server --cursor-autohide-fs-only --cursor-autohide=1000 --no-keepaspect-window --no-window-dragging "$VIDEO_PATH" &

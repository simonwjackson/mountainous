#!/usr/bin/env bash
# steam-cage - Launch Steam inside cage -> sway (kiosk-style)
#
# Usage: steam-cage [steam-args...]
#
# All arguments are passed directly to Steam.
#
# Controls inside the session:
#   Super+Shift+E - Exit the session
#   Super+Shift+Q - Kill focused window
#   Super+Return  - Open foot terminal

set -euo pipefail

# All arguments passed through to steam
STEAM_ARGS="$*"

# Set up environment
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Verify Wayland socket exists
if [[ ! -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]]; then
  echo "Error: Wayland socket not found at ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" >&2
  echo "Make sure you're running this from within a Wayland session (e.g., Hyprland)" >&2
  exit 1
fi

# Use STEAM_REAL_PATH if set (from wrapper), otherwise fall back to 'steam' in PATH
STEAM_BIN="${STEAM_REAL_PATH:-steam}"

# Determine GPU launcher
# Use nvidia-offload if available (for NVIDIA Optimus/Prime systems)
if command -v nvidia-offload &>/dev/null; then
  STEAM_LAUNCHER="nvidia-offload $STEAM_BIN"
else
  STEAM_LAUNCHER="$STEAM_BIN"
fi

# Create temporary sway config
SWAY_CONFIG=$(mktemp --suffix=.sway-steam)
trap 'rm -f "$SWAY_CONFIG"' EXIT

cat >"$SWAY_CONFIG" <<EOF
# Minimal sway config for Steam kiosk mode
# No window decorations for clean look
default_border none
default_floating_border none
titlebar_border_thickness 0
titlebar_padding 0

# Hide cursor after 3 seconds of inactivity
seat * hide_cursor 3000

# Launch Steam
exec ${STEAM_LAUNCHER} ${STEAM_ARGS}

# Keybindings
bindsym Mod4+Return exec foot
bindsym Mod4+Shift+q kill
bindsym Mod4+Shift+e exit
EOF

# Launch cage with sway
exec cage -s -- sway -c "$SWAY_CONFIG"

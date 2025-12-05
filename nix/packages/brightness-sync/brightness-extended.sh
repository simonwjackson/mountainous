#!/usr/bin/env bash

# brightness-extended - Seamless brightness control with software dimming below hardware minimum
# Uses hardware backlight until minimum, then applies gamma overlay via Hyprland shader

set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/brightness-extended-state"
SHADER_FILE="${XDG_RUNTIME_DIR:-/tmp}/brightness-dimmer.glsl"

# Configuration
HARDWARE_MIN=5 # Hardware backlight minimum (percent)
SOFTWARE_MIN=1 # Lowest software dim level (percent)
STEP_DEFAULT=5

# Detect backlight device
detect_backlight() {
  local dir="/sys/class/backlight"
  for device in "$dir"/amdgpu_bl* "$dir"/intel_backlight "$dir"/acpi_video* "$dir"/*; do
    if [ -d "$device" ] && [ -f "$device/brightness" ]; then
      basename "$device"
      return 0
    fi
  done
  return 1
}

BACKLIGHT_DEVICE="${BACKLIGHT_DEVICE:-$(detect_backlight 2>/dev/null || echo "")}"

# Get hardware brightness (percent)
get_hw_brightness() {
  if command -v brightnessctl &>/dev/null; then
    if [ -n "$BACKLIGHT_DEVICE" ]; then
      brightnessctl -m -d "$BACKLIGHT_DEVICE" 2>/dev/null | cut -d, -f4 | tr -d '%'
    else
      brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'
    fi
  else
    echo "$HARDWARE_MIN"
  fi
}

# Set hardware brightness (percent)
set_hw_brightness() {
  local level="$1"
  level=$((level < HARDWARE_MIN ? HARDWARE_MIN : level))
  level=$((level > 100 ? 100 : level))

  if command -v brightnessctl &>/dev/null; then
    if [ -n "$BACKLIGHT_DEVICE" ]; then
      brightnessctl -q -d "$BACKLIGHT_DEVICE" set "${level}%"
    else
      brightnessctl -q set "${level}%"
    fi
  fi
}

# Generate dimmer shader with given opacity (0.0 = black, 1.0 = full brightness)
generate_shader() {
  local opacity="$1"
  cat >"$SHADER_FILE" <<EOF
#version 300 es
precision mediump float;

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 c = texture(tex, v_texcoord);
    c.rgb *= ${opacity};
    fragColor = c;
}
EOF
}

# Apply or remove dimming shader
apply_shader() {
  local opacity="$1"

  if [ "$opacity" = "1.0" ] || [ "$opacity" = "1" ]; then
    # Full brightness - restore vibrance shader via hyprshade
    rm -f "$SHADER_FILE"
    if command -v hyprshade &>/dev/null; then
      hyprshade on vibrance >/dev/null 2>&1 || hyprctl keyword decoration:screen_shader "" >/dev/null 2>&1 || true
    else
      hyprctl keyword decoration:screen_shader "" >/dev/null 2>&1 || true
    fi
  else
    # Apply dimming shader
    generate_shader "$opacity"
    hyprctl keyword decoration:screen_shader "$SHADER_FILE" >/dev/null 2>&1 || true
  fi
}

# Get current extended brightness (0-100, where 0-HARDWARE_MIN uses software dim)
get_brightness() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    get_hw_brightness
  fi
}

# Set extended brightness (0-100)
set_brightness() {
  local target="$1"
  target=$((target < SOFTWARE_MIN ? SOFTWARE_MIN : target))
  target=$((target > 100 ? 100 : target))

  echo "$target" >"$STATE_FILE"

  if [ "$target" -ge "$HARDWARE_MIN" ]; then
    # Above hardware minimum - use hardware, disable shader
    set_hw_brightness "$target"
    apply_shader 1.0
  else
    # Below hardware minimum - keep hardware at min, use shader
    set_hw_brightness "$HARDWARE_MIN"
    # Map SOFTWARE_MIN-HARDWARE_MIN to opacity 0.1-1.0
    # e.g., target=1 (SOFTWARE_MIN) -> opacity=0.1, target=5 (HARDWARE_MIN) -> opacity=1.0
    local range=$((HARDWARE_MIN - SOFTWARE_MIN))
    local position=$((target - SOFTWARE_MIN))
    local opacity
    opacity=$(echo "scale=2; 0.1 + (0.9 * $position / $range)" | bc)
    apply_shader "$opacity"
  fi
}

# Increase brightness
increase() {
  local step="${1:-$STEP_DEFAULT}"
  local current
  current=$(get_brightness)
  set_brightness $((current + step))
}

# Decrease brightness
decrease() {
  local step="${1:-$STEP_DEFAULT}"
  local current
  current=$(get_brightness)
  set_brightness $((current - step))
}

# Show current status
status() {
  local current hw_level
  current=$(get_brightness)
  hw_level=$(get_hw_brightness)

  echo "Extended brightness: ${current}%"
  echo "Hardware brightness: ${hw_level}%"

  if [ "$current" -lt "$HARDWARE_MIN" ]; then
    echo "Mode: Software dimming (shader active)"
  else
    echo "Mode: Hardware backlight"
  fi
}

# Main
case "${1:-status}" in
  get)
    get_brightness
    ;;
  set)
    set_brightness "${2:?Usage: $0 set <0-100>}"
    ;;
  up)
    increase "${2:-$STEP_DEFAULT}"
    ;;
  down)
    decrease "${2:-$STEP_DEFAULT}"
    ;;
  status)
    status
    ;;
  -h | --help)
    cat <<EOF
brightness-extended - Seamless brightness with software dimming

Usage: $0 <command> [value]

Commands:
  get       Get current brightness (0-100)
  set N     Set brightness to N percent
  up [N]    Increase brightness by N (default: 5)
  down [N]  Decrease brightness by N (default: 5)
  status    Show detailed status

Brightness 0-${HARDWARE_MIN}% uses software dimming (shader)
Brightness ${HARDWARE_MIN}-100% uses hardware backlight
EOF
    ;;
  *)
    echo "Unknown command: $1" >&2
    exit 1
    ;;
esac

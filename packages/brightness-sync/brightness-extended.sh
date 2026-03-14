#!/usr/bin/env bash

# brightness-extended - Seamless brightness control with software dimming below hardware minimum
# Uses hardware backlight until minimum, then applies gamma overlay via Hyprland shader

set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/brightness-extended-state"
SHADER_FILE="${XDG_RUNTIME_DIR:-/tmp}/brightness-dimmer.glsl"

# Configuration
# User-facing scale: 0-100
#   0-19:   Software dimming (20 fine-grained steps, shader opacity 0.02-0.95)
#   20-100: Hardware brightness (maps to 5-100% backlight)
SOFTWARE_STEPS=20  # Number of software dimming levels (0 to SOFTWARE_STEPS-1)
HARDWARE_MIN_PCT=5 # Lowest hardware backlight percentage
STEP_DEFAULT=1

# Command to run when exiting software dimming (e.g., restore vibrance shader)
RESTORE_SHADER_CMD="${RESTORE_SHADER_CMD:-}"

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
    echo "$HARDWARE_MIN_PCT"
  fi
}

# Set hardware brightness (percent, clamped to HARDWARE_MIN_PCT-100)
set_hw_brightness() {
  local level="$1"
  level=$((level < HARDWARE_MIN_PCT ? HARDWARE_MIN_PCT : level))
  level=$((level > 100 ? 100 : level))

  if command -v brightnessctl &>/dev/null; then
    if [ -n "$BACKLIGHT_DEVICE" ]; then
      brightnessctl -q -d "$BACKLIGHT_DEVICE" set "${level}%"
    else
      brightnessctl -q set "${level}%"
    fi
  fi
}

# Generate dimming shader
generate_dimmer_shader() {
  local opacity="$1"
  cat >"$SHADER_FILE" <<EOF
#version 300 es
precision highp float;

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

# Apply dimming shader or restore default
apply_shader() {
  local opacity="$1"

  if [ "$opacity" = "1.0" ] || [ "$opacity" = "1" ]; then
    # Not dimming - clear shader and run restore command if configured
    rm -f "$SHADER_FILE"
    if [ -n "$RESTORE_SHADER_CMD" ]; then
      eval "$RESTORE_SHADER_CMD" >/dev/null 2>&1 || true
    else
      hyprctl keyword decoration:screen_shader "" >/dev/null 2>&1 || true
    fi
  else
    # Dimming - apply dimmer shader
    generate_dimmer_shader "$opacity"
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
# 0-(SOFTWARE_STEPS-1): Software dimming with shader
# SOFTWARE_STEPS-100: Hardware brightness (mapped to HARDWARE_MIN_PCT-100%)
set_brightness() {
  local target="$1"
  target=$((target < 0 ? 0 : target))
  target=$((target > 100 ? 100 : target))

  # Get previous brightness to detect mode transitions
  local previous=0
  if [ -f "$STATE_FILE" ]; then
    previous=$(cat "$STATE_FILE")
  fi

  echo "$target" >"$STATE_FILE"

  local was_dimming=$([ "$previous" -lt "$SOFTWARE_STEPS" ] && echo 1 || echo 0)
  local now_dimming=$([ "$target" -lt "$SOFTWARE_STEPS" ] && echo 1 || echo 0)

  if [ "$target" -ge "$SOFTWARE_STEPS" ]; then
    # Hardware range: map SOFTWARE_STEPS-100 to HARDWARE_MIN_PCT-100%
    local hw_brightness
    hw_brightness=$(awk "BEGIN {printf \"%.0f\", $HARDWARE_MIN_PCT + ($target - $SOFTWARE_STEPS) * (100 - $HARDWARE_MIN_PCT) / (100 - $SOFTWARE_STEPS)}")
    set_hw_brightness "$hw_brightness"
    # Only restore shader when transitioning OUT of software dimming
    if [ "$was_dimming" = "1" ]; then
      apply_shader 1.0
    fi
  else
    # Software dimming range: 0 to SOFTWARE_STEPS-1
    set_hw_brightness "$HARDWARE_MIN_PCT"
    local opacity
    opacity=$(awk "BEGIN {printf \"%.3f\", 0.02 + (0.93 * $target / ($SOFTWARE_STEPS - 1))}")
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

  echo "Extended brightness: ${current}/100"
  echo "Hardware brightness: ${hw_level}%"

  if [ "$current" -lt "$SOFTWARE_STEPS" ]; then
    local opacity
    opacity=$(awk "BEGIN {printf \"%.3f\", 0.02 + (0.93 * $current / ($SOFTWARE_STEPS - 1))}")
    echo "Mode: Software dimming (shader opacity: ${opacity})"
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
  set N     Set brightness to N (0-100)
  up [N]    Increase brightness by N (default: 1)
  down [N]  Decrease brightness by N (default: 1)
  status    Show detailed status

Scale:
  0-$((SOFTWARE_STEPS - 1)):   Software dimming ($SOFTWARE_STEPS fine steps, shader opacity 0.02-0.95)
  ${SOFTWARE_STEPS}-100: Hardware backlight (maps to ${HARDWARE_MIN_PCT}-100%)
EOF
    ;;
  *)
    echo "Unknown command: $1" >&2
    exit 1
    ;;
esac

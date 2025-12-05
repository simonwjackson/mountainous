#!/usr/bin/env bash

# brightness-sync - Synchronize brightness across internal and external displays
# Supports both backlight (internal) and DDC/CI (external) displays
# All brightness changes are executed in parallel for simultaneous updates

set -euo pipefail

PROGRAM_NAME="brightness-sync"
VERSION="1.0.0"

# Configuration
EXTERNAL_DISPLAY_ID="1" # DDC display ID
MIN_BRIGHTNESS=5
MAX_BRIGHTNESS=100

# Auto-detect internal backlight device
detect_backlight() {
  local backlight_dir="/sys/class/backlight"

  # Check if backlight directory exists
  if [ ! -d "$backlight_dir" ]; then
    return 1
  fi

  # Try common backlight devices in order of preference
  # amdgpu_bl* for AMD GPUs, intel_backlight for Intel, acpi_video* as fallback
  for device in "$backlight_dir"/amdgpu_bl* "$backlight_dir"/intel_backlight "$backlight_dir"/acpi_video* "$backlight_dir"/*; do
    if [ -d "$device" ] && [ -f "$device/brightness" ]; then
      basename "$device"
      return 0
    fi
  done

  return 1
}

INTERNAL_DISPLAY="${INTERNAL_DISPLAY:-$(detect_backlight 2>/dev/null || echo "")}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Help message
show_help() {
  cat <<EOF
$PROGRAM_NAME v$VERSION - Synchronize brightness across all displays

Usage: $PROGRAM_NAME [OPTIONS] [COMMAND] [VALUE]

Commands:
    get         Get current brightness percentage
    set VALUE   Set brightness to VALUE (0-100)
    up [STEP]   Increase brightness by STEP (default: 5)
    down [STEP] Decrease brightness by STEP (default: 5)
    sync        Sync external display to match internal display
    watch       Monitor and auto-sync brightness changes

Options:
    -h, --help     Show this help message
    -v, --version  Show version information
    -q, --quiet    Suppress output
    -d, --daemon   Run in daemon mode (auto-sync)

Examples:
    $PROGRAM_NAME set 50        # Set all displays to 50%
    $PROGRAM_NAME up 10         # Increase brightness by 10%
    $PROGRAM_NAME down          # Decrease brightness by 5%
    $PROGRAM_NAME sync          # Sync external to internal
    $PROGRAM_NAME watch         # Auto-sync on changes

EOF
}

# Check for required tools
check_dependencies() {
  local missing_deps=()

  if ! command -v ddcutil &>/dev/null; then
    missing_deps+=("ddcutil")
  fi

  # Check if we have any way to control internal display
  if ! command -v brightnessctl &>/dev/null &&
    ! command -v brillo &>/dev/null; then
    if [ -z "$INTERNAL_DISPLAY" ]; then
      missing_deps+=("brightnessctl/brillo (no backlight device detected)")
    elif [ ! -d "/sys/class/backlight/$INTERNAL_DISPLAY" ]; then
      missing_deps+=("brightnessctl/brillo or valid backlight sysfs interface (detected: $INTERNAL_DISPLAY)")
    fi
  fi

  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing dependencies: ${missing_deps[*]}${NC}" >&2
    echo "Available backlights: $(ls /sys/class/backlight/ 2>/dev/null || echo 'none')" >&2
    echo "Please install the required tools and try again." >&2
    exit 1
  fi
}

# Get internal display brightness (0-100)
get_internal_brightness() {
  if command -v brightnessctl &>/dev/null; then
    # brightnessctl auto-detects the backlight device if not specified
    if [ -n "$INTERNAL_DISPLAY" ]; then
      brightnessctl -m -d "$INTERNAL_DISPLAY" 2>/dev/null | cut -d, -f4 | tr -d '%'
    else
      brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'
    fi
  elif command -v brillo &>/dev/null; then
    brillo -q
  else
    # Direct sysfs access as fallback
    if [ -z "$INTERNAL_DISPLAY" ]; then
      echo "0"
      return 1
    fi
    local current max percentage
    current=$(cat "/sys/class/backlight/$INTERNAL_DISPLAY/brightness")
    max=$(cat "/sys/class/backlight/$INTERNAL_DISPLAY/max_brightness")
    percentage=$(awk -v cur="$current" -v max="$max" 'BEGIN {printf "%.0f", (cur / max) * 100}')
    echo "$percentage"
  fi
}

# Get external display brightness (0-100)
get_external_brightness() {
  local result
  result=$(sudo ddcutil getvcp 10 --display "$EXTERNAL_DISPLAY_ID" 2>/dev/null |
    grep -oP 'current value =\s*\K\d+' || echo "0")
  echo "$result"
}

# Set internal display brightness (0-100)
set_internal_brightness() {
  local brightness="$1"
  brightness=$(max "$MIN_BRIGHTNESS" "$brightness")
  brightness=$(min "$MAX_BRIGHTNESS" "$brightness")

  if command -v brightnessctl &>/dev/null; then
    # brightnessctl auto-detects the backlight device if not specified
    if [ -n "$INTERNAL_DISPLAY" ]; then
      brightnessctl -q -d "$INTERNAL_DISPLAY" set "${brightness}%"
    else
      brightnessctl -q set "${brightness}%"
    fi
  elif command -v brillo &>/dev/null; then
    sudo brillo -S "$brightness" -q
  else
    if [ -z "$INTERNAL_DISPLAY" ]; then
      echo -e "${RED}Error: No backlight device detected${NC}" >&2
      return 1
    fi
    local max_brightness
    max_brightness=$(cat "/sys/class/backlight/$INTERNAL_DISPLAY/max_brightness")
    local raw_value=$((brightness * max_brightness / 100))
    echo "$raw_value" | sudo tee "/sys/class/backlight/$INTERNAL_DISPLAY/brightness" >/dev/null
  fi
}

# Set external display brightness (0-100)
set_external_brightness() {
  local brightness="$1"
  brightness=$(max "$MIN_BRIGHTNESS" "$brightness")
  brightness=$(min "$MAX_BRIGHTNESS" "$brightness")

  sudo ddcutil setvcp 10 "$brightness" --display "$EXTERNAL_DISPLAY_ID" 2>/dev/null || {
    echo -e "${YELLOW}Warning: Could not set external display brightness${NC}" >&2
    return 1
  }
}

# Math helper functions
min() { echo $(($1 < $2 ? $1 : $2)); }
max() { echo $(($1 > $2 ? $1 : $2)); }

# Set brightness on all displays
set_all_brightness() {
  local target_brightness="$1"
  local quiet="${2:-false}"

  target_brightness=$(max "$MIN_BRIGHTNESS" "$target_brightness")
  target_brightness=$(min "$MAX_BRIGHTNESS" "$target_brightness")

  if [ "$quiet" != "true" ]; then
    echo -e "${GREEN}Setting brightness to ${target_brightness}%${NC}"
  fi

  # Set both displays in parallel
  local internal_pid external_pid
  local internal_error=0 external_error=0

  # Launch internal display change in background
  (set_internal_brightness "$target_brightness") &
  internal_pid=$!

  # Launch external display change in background
  (set_external_brightness "$target_brightness" 2>/dev/null || echo "EXTERNAL_ERROR") &
  external_pid=$!

  # Wait for both to complete
  wait $internal_pid
  internal_error=$?

  # Check if external had an error
  if wait $external_pid; then
    external_error=0
  else
    external_error=1
  fi

  if [ "$quiet" != "true" ]; then
    if [ $internal_error -eq 0 ] && [ $external_error -eq 0 ]; then
      echo -e "${GREEN}✓ Brightness synchronized at ${target_brightness}%${NC}"
    elif [ $external_error -ne 0 ]; then
      echo -e "${YELLOW}⚠ Internal display set to ${target_brightness}%, but external display failed${NC}"
    fi
  fi
}

# Increase brightness
increase_brightness() {
  local step="${1:-5}"
  local current
  current=$(get_internal_brightness)
  local new_brightness=$((current + step))
  set_all_brightness "$new_brightness"
}

# Decrease brightness
decrease_brightness() {
  local step="${1:-5}"
  local current
  current=$(get_internal_brightness)
  local new_brightness=$((current - step))
  set_all_brightness "$new_brightness"
}

# Sync external to internal
sync_brightness() {
  local internal_brightness
  internal_brightness=$(get_internal_brightness)

  echo -e "${GREEN}Syncing external display to ${internal_brightness}%${NC}"
  set_external_brightness "$internal_brightness"
  echo -e "${GREEN}✓ Displays synchronized${NC}"
}

# Get current brightness of all displays
get_brightness() {
  local internal external
  local internal_result external_result

  # Get both brightness values in parallel
  get_internal_brightness >/tmp/brightness_internal_$$ &
  local internal_pid=$!

  get_external_brightness >/tmp/brightness_external_$$ &
  local external_pid=$!

  # Wait for both to complete
  wait $internal_pid
  wait $external_pid

  # Read results
  internal=$(cat /tmp/brightness_internal_$$ 2>/dev/null || echo "0")
  external=$(cat /tmp/brightness_external_$$ 2>/dev/null || echo "0")

  # Clean up temp files
  rm -f /tmp/brightness_internal_$$ /tmp/brightness_external_$$

  echo "Internal display: ${internal}%"
  echo "External display: ${external}%"

  if [ "$internal" != "$external" ]; then
    echo -e "${YELLOW}⚠ Displays are not synchronized${NC}"
  else
    echo -e "${GREEN}✓ Displays are synchronized${NC}"
  fi
}

# Watch for brightness changes and auto-sync
watch_brightness() {
  echo -e "${GREEN}Watching for brightness changes (Ctrl+C to stop)...${NC}"

  local last_internal
  last_internal=$(get_internal_brightness)

  while true; do
    sleep 0.5
    local current_internal
    current_internal=$(get_internal_brightness)

    if [ "$current_internal" != "$last_internal" ]; then
      echo -e "${YELLOW}Detected brightness change: ${last_internal}% → ${current_internal}%${NC}"
      set_external_brightness "$current_internal"
      echo -e "${GREEN}✓ External display synchronized${NC}"
      last_internal="$current_internal"
    fi
  done
}

# Main function
main() {
  local quiet=false
  local daemon=false

  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h | --help)
        show_help
        exit 0
        ;;
      -v | --version)
        echo "$PROGRAM_NAME v$VERSION"
        exit 0
        ;;
      -q | --quiet)
        quiet=true
        shift
        ;;
      -d | --daemon)
        daemon=true
        shift
        ;;
      get)
        check_dependencies
        get_brightness
        exit 0
        ;;
      set)
        check_dependencies
        shift
        if [[ $# -eq 0 ]]; then
          echo -e "${RED}Error: 'set' requires a brightness value (0-100)${NC}" >&2
          exit 1
        fi
        set_all_brightness "$1" "$quiet"
        exit 0
        ;;
      up)
        check_dependencies
        shift
        increase_brightness "${1:-5}"
        exit 0
        ;;
      down)
        check_dependencies
        shift
        decrease_brightness "${1:-5}"
        exit 0
        ;;
      sync)
        check_dependencies
        sync_brightness
        exit 0
        ;;
      watch)
        check_dependencies
        watch_brightness
        exit 0
        ;;
      *)
        echo -e "${RED}Error: Unknown command '$1'${NC}" >&2
        echo "Use '$PROGRAM_NAME --help' for usage information" >&2
        exit 1
        ;;
    esac
  done

  # If no command given, show current status
  check_dependencies
  get_brightness
}

# Run main function
main "$@"

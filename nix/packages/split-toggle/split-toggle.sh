#!/usr/bin/env bash
set -euo pipefail

# Constants
readonly GOLDEN_RATIO="0.61803"
readonly EVEN_SPLIT="0.5"
readonly THRESHOLD="0.559"

# Global variables
DEBUG=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      DEBUG=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [-v|--verbose] [-h|--help]"
      echo "Toggle between golden ratio and even split layouts"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Debug logging function
debug() {
  $DEBUG && echo "[DEBUG] $*" >&2 || true
}

# Error function
error() {
  echo "Error: $*" >&2
  exit 1
}

# Get monitor information
get_monitor_info() {
  local monitor_data
  monitor_data=$(hyprctl --instance 0 monitors -j | jq -r '.[] | select(.focused == true) | "\(.width),\(.scale)"') || error "Failed to get monitor info"

  [ -z "$monitor_data" ] || [ "$monitor_data" = "null," ] && error "No focused monitor found"

  echo "$monitor_data"
}

# Get current window layout information
get_window_layout() {
  local workspace_id orientation windows_info

  workspace_id=$(hyprctl --instance 0 activeworkspace -j | jq -r '.id') || error "Failed to get workspace ID"
  orientation=$(hyprctl --instance 0 getoption master:orientation -j | jq -r '.str') || error "Failed to get orientation"

  # Get windows in current workspace (non-floating only)
  windows_info=$(hyprctl --instance 0 clients -j | jq -r --argjson ws "$workspace_id" '
    [.[] | select(.workspace.id == $ws and .floating == false)] |
    if length == 0 then empty else
      . as $windows |
      (map(.at[0]) | min) as $minx |
      (map(.at[0] + .size[0]) | max) as $maxx |
      {
        windows: (map("\(.size[0]),\(.at[0]),\(.class)") | sort_by(split(",")[1] | tonumber)),
        area_width: ($maxx - $minx),
        orientation: "'"$orientation"'"
      }
    end
  ') || error "Failed to get window layout"

  echo "$windows_info"
}

# Determine target ratio based on current state
determine_target_ratio() {
  local current_ratio="$1"
  local diff_golden diff_even

  diff_golden=$(awk "BEGIN {d=$current_ratio-$GOLDEN_RATIO; printf \"%.5f\", (d<0) ? -d : d}")
  diff_even=$(awk "BEGIN {d=$current_ratio-$EVEN_SPLIT; printf \"%.5f\", (d<0) ? -d : d}")

  if [ "$(awk "BEGIN {print ($diff_golden < $diff_even) ? 1 : 0}")" = "1" ]; then
    debug "Closer to golden ratio (diff: $diff_golden), switching to even split"
    echo "$EVEN_SPLIT"
  else
    debug "Closer to even split (diff: $diff_even), switching to golden ratio"
    echo "$GOLDEN_RATIO"
  fi
}

# Apply the new ratio
apply_ratio() {
  local new_ratio="$1"
  debug "Setting mfact to $new_ratio"
  hyprctl --instance 0 dispatch layoutmsg "mfact exact $new_ratio" || error "Failed to apply ratio"
}

# Main execution
main() {
  local monitor_info physical_width scale logical_width
  local layout_info windows_data area_width orientation
  local master_info master_width actual_ratio new_ratio

  # Get monitor information
  monitor_info=$(get_monitor_info)
  physical_width=$(echo "$monitor_info" | cut -d',' -f1)
  scale=$(echo "$monitor_info" | cut -d',' -f2)
  logical_width=$(awk "BEGIN {printf \"%.0f\", $physical_width / $scale}")

  debug "Monitor: ${physical_width}px physical, ${logical_width}px logical (scale $scale)"

  # Get window layout
  layout_info=$(get_window_layout)

  if [ -z "$layout_info" ]; then
    debug "No windows found, using config fallback"
    local current_mfact
    current_mfact=$(hyprctl --instance 0 getoption master:mfact -j | jq -r '.float') || error "Failed to get current mfact"

    if [ "$(awk "BEGIN {print ($current_mfact > $THRESHOLD) ? 1 : 0}")" = "1" ]; then
      new_ratio="$EVEN_SPLIT"
    else
      new_ratio="$GOLDEN_RATIO"
    fi
    debug "Config fallback: switching to $new_ratio"
  else
    # Parse layout information
    orientation=$(echo "$layout_info" | jq -r '.orientation')
    area_width=$(echo "$layout_info" | jq -r '.area_width')

    # Get master window info based on orientation
    if [ "$orientation" = "right" ]; then
      master_info=$(echo "$layout_info" | jq -r '.windows | last')
      debug "Orientation: right (master is rightmost)"
    else
      master_info=$(echo "$layout_info" | jq -r '.windows | first')
      debug "Orientation: left (master is leftmost)"
    fi

    master_width=$(echo "$master_info" | cut -d',' -f1)
    actual_ratio=$(awk "BEGIN {printf \"%.5f\", $master_width / $area_width}")

    debug "Master window: ${master_width}px logical"
    debug "Window area: ${area_width}px total"
    debug "Current ratio: $actual_ratio"

    new_ratio=$(determine_target_ratio "$actual_ratio")
  fi

  apply_ratio "$new_ratio"
  $DEBUG || echo "Layout toggled to ratio: $new_ratio"
}

main "$@"

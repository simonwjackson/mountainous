#!/usr/bin/env bash

# Parse arguments
DIRECTION="${1:-up}"
TARGET="${2:-focused}"  # focused, monitor name, or "all"

# Function to get monitor information based on target
get_target_monitors() {
  local target="$1"

  if [ "$target" = "all" ] || [ "$target" = "--all" ]; then
    # Return all monitors
    hyprctl --instance 0 monitors -j | jq -r '.[] | "\(.name),\(.width)x\(.height)@\(.refreshRate),\(.x)x\(.y),\(.scale),\(.transform)"'
  elif [ "$target" = "focused" ]; then
    # Return focused monitor
    hyprctl --instance 0 monitors -j | jq -r '.[] | select(.focused == true) | "\(.name),\(.width)x\(.height)@\(.refreshRate),\(.x)x\(.y),\(.scale),\(.transform)"'
  else
    # Return specific monitor by name
    hyprctl --instance 0 monitors -j | jq -r --arg name "$target" '.[] | select(.name == $name) | "\(.name),\(.width)x\(.height)@\(.refreshRate),\(.x)x\(.y),\(.scale),\(.transform)"'
  fi
}

# Get monitors based on target
MONITOR_INFO=$(get_target_monitors "$TARGET")

if [ -z "$MONITOR_INFO" ]; then
  if [ "$TARGET" = "focused" ]; then
    echo "No focused monitor found"
  elif [ "$TARGET" = "all" ] || [ "$TARGET" = "--all" ]; then
    echo "No monitors found"
  else
    echo "Monitor '$TARGET' not found"
  fi
  exit 1
fi

# Function to get valid scales for a resolution
get_valid_scales() {
  local width=$1
  local height=$2
  local transform=$3

  # Adjust resolution key based on rotation
  local resolution_key
  if [ "$transform" = "1" ] || [ "$transform" = "3" ]; then
    resolution_key="${height}x${width}"
  else
    resolution_key="${width}x${height}"
  fi

  # Return valid scales based on resolution
  case "$resolution_key" in
    "2024x2560"|"2560x2024")
      echo "0.5 1.0 1.333333 1.6 2.0"
      ;;
    "2880x1800"|"1800x2880")
      echo "1.0 1.125 1.25 1.333333 1.5 1.6 1.8 2.0"
      ;;
    "1920x1080"|"1080x1920")
      echo "0.5 0.75 1.0 1.2 1.25 1.5 2.0"
      ;;
    "3840x2160"|"2160x3840")
      echo "0.5 1.0 1.25 1.5 2.0 2.5 3.0"
      ;;
    "2560x1440"|"1440x2560")
      echo "0.5 1.0 1.25 2.0"
      ;;
    *)
      # Calculate dynamically for unknown resolutions
      local candidate_scales="0.5 0.75 1.0 1.2 1.25 1.333333 1.5 1.6 2.0"
      local valid_scales=""

      for scale in $candidate_scales; do
        if [ "$(awk "BEGIN {print ($width % $scale == 0 && $height % $scale == 0) ? 1 : 0}")" = "1" ]; then
          valid_scales="$valid_scales $scale"
        fi
      done

      # Fallback if no valid scales found
      if [ -z "$valid_scales" ]; then
        echo "0.5 1.0 2.0"
      else
        echo "$valid_scales"
      fi
      ;;
  esac
}

# Function to find scale intersection for multiple monitors
get_scale_intersection() {
  local first=true
  local intersection=""

  while IFS=',' read -r name resolution position scale transform; do
    local width=$(echo "$resolution" | cut -d'x' -f1)
    local height=$(echo "$resolution" | cut -d'x' -f2 | cut -d'@' -f1)
    local monitor_scales=$(get_valid_scales "$width" "$height" "$transform")

    if [ "$first" = true ]; then
      intersection="$monitor_scales"
      first=false
    else
      # Find intersection
      local new_intersection=""
      for scale in $intersection; do
        if echo "$monitor_scales" | grep -q "\b$scale\b"; then
          new_intersection="$new_intersection $scale"
        fi
      done
      intersection="$new_intersection"
    fi
  done <<< "$MONITOR_INFO"

  # Fallback if no intersection
  if [ -z "$intersection" ]; then
    echo "1.0 2.0"
  else
    echo "$intersection"
  fi
}

# Function to apply scale to a single monitor
apply_monitor_scale() {
  local monitor_line="$1"
  local target_scale="$2"
  local all_monitors_info="$3"  # Optional: all monitor info for position recalculation

  local name=$(echo "$monitor_line" | cut -d',' -f1)
  local resolution=$(echo "$monitor_line" | cut -d',' -f2)
  local position=$(echo "$monitor_line" | cut -d',' -f3)
  local current_scale=$(echo "$monitor_line" | cut -d',' -f4)
  local transform=$(echo "$monitor_line" | cut -d',' -f5)

  # Check if we need to recalculate position for eDP-1 in multi-monitor setup
  local new_position="$position"
  if [ -n "$all_monitors_info" ] && [ "$name" = "eDP-1" ]; then
    # Look for DP monitor to calculate relative position
    local dp_monitor=$(echo "$all_monitors_info" | grep -E "^DP-[0-9]")
    if [ -n "$dp_monitor" ]; then
      local dp_resolution=$(echo "$dp_monitor" | cut -d',' -f2)
      local dp_width=$(echo "$dp_resolution" | cut -d'x' -f1)
      local dp_height=$(echo "$dp_resolution" | cut -d'x' -f2 | cut -d'@' -f1)

      # eDP-1 effective width after 270 rotation (2560px physical)
      local edp_width=2560

      # Calculate centered x-position: (DP_width - eDP_width) / (2 * scale)
      local new_x=$(awk "BEGIN {printf \"%.0f\", ($dp_width - $edp_width) / (2 * $target_scale)}")

      # Calculate y-position: DP height / new scale
      local new_y=$(awk "BEGIN {printf \"%.0f\", $dp_height / $target_scale}")

      new_position="${new_x}x${new_y}"

      echo "  Recalculating eDP-1 position: $position -> $new_position (centered under DP, scale: $target_scale)"
    fi
  fi

  if [ "$target_scale" != "$current_scale" ]; then
    echo "-> $name: Applying scale $current_scale -> $target_scale (transform: $transform)"
    hyprctl --instance 0 keyword monitor "$name,$resolution,$new_position,$target_scale,transform,$transform"

    # Verify the scale was applied
    sleep 0.1
    local actual_scale=$(hyprctl --instance 0 monitors -j | jq -r --arg name "$name" '.[] | select(.name == $name) | .scale')
    local actual_normalized=$(awk "BEGIN {printf \"%.2f\", $actual_scale}")
    local target_normalized=$(awk "BEGIN {printf \"%.2f\", $target_scale}")

    if [ "$actual_normalized" = "$target_normalized" ]; then
      echo "  Scale successfully changed to $target_scale"
    else
      echo "  Warning: Scale change may have failed. Current: $actual_scale, Expected: $target_scale"
    fi
  else
    echo "-> $name: Scale unchanged ($current_scale)"
  fi
}

# Main processing logic
if [ "$TARGET" = "all" ] || [ "$TARGET" = "--all" ]; then
  # Handle multiple monitors with intersection
  monitor_count=$(echo "$MONITOR_INFO" | wc -l)
  if [ "$monitor_count" -gt 1 ]; then
    echo "Detecting $monitor_count monitors..."
    intersection=$(get_scale_intersection)
    echo "Common scales: [$intersection]"

    # Convert to array
    read -ra VALID_SCALES <<< "$intersection"

    if [ ${#VALID_SCALES[@]} -le 1 ]; then
      echo "Error: No common scales available for synchronized scaling"
      exit 1
    fi

    # Find the current common scale (or closest)
    # For simplicity, use the first monitor's current scale as reference
    first_monitor=$(echo "$MONITOR_INFO" | head -n1)
    current_scale=$(echo "$first_monitor" | cut -d',' -f4)

    # Find closest scale in intersection
    current_index=0
    min_diff=999
    for i in "${!VALID_SCALES[@]}"; do
      scale="${VALID_SCALES[$i]}"
      diff=$(awk "BEGIN {printf \"%.6f\", sqrt(($current_scale - $scale)^2)}")
      is_smaller=$(awk "BEGIN {print ($diff < $min_diff) ? 1 : 0}")
      if [ "$is_smaller" = "1" ]; then
        min_diff=$diff
        current_index=$i
      fi
    done

    # Calculate new index
    if [ "$DIRECTION" = "up" ]; then
      new_index=$((current_index + 1))
      if [ $new_index -ge ${#VALID_SCALES[@]} ]; then
        new_index=$((${#VALID_SCALES[@]} - 1))
        echo "Already at maximum common scale"
      fi
    else
      new_index=$((current_index - 1))
      if [ $new_index -lt 0 ]; then
        new_index=0
        echo "Already at minimum common scale"
      fi
    fi

    target_scale="${VALID_SCALES[$new_index]}"
    echo "Applying scale $target_scale to all monitors:"

    # Apply to all monitors
    while IFS= read -r monitor_line; do
      apply_monitor_scale "$monitor_line" "$target_scale" "$MONITOR_INFO"
    done <<< "$MONITOR_INFO"
  else
    # Single monitor, fall through to individual logic
    TARGET="focused"
  fi
fi

# Handle individual monitor (focused or named)
if [ "$TARGET" != "all" ] && [ "$TARGET" != "--all" ]; then
  # Parse single monitor info
  name=$(echo "$MONITOR_INFO" | cut -d',' -f1)
  resolution=$(echo "$MONITOR_INFO" | cut -d',' -f2)
  position=$(echo "$MONITOR_INFO" | cut -d',' -f3)
  current_scale=$(echo "$MONITOR_INFO" | cut -d',' -f4)
  transform=$(echo "$MONITOR_INFO" | cut -d',' -f5)

  width=$(echo "$resolution" | cut -d'x' -f1)
  height=$(echo "$resolution" | cut -d'x' -f2 | cut -d'@' -f1)

  # Get valid scales for this monitor
  valid_scales_str=$(get_valid_scales "$width" "$height" "$transform")
  read -ra VALID_SCALES <<< "$valid_scales_str"

  # Find current scale index
  current_index=0
  min_diff=999
  for i in "${!VALID_SCALES[@]}"; do
    scale="${VALID_SCALES[$i]}"
    diff=$(awk "BEGIN {printf \"%.6f\", sqrt(($current_scale - $scale)^2)}")
    is_smaller=$(awk "BEGIN {print ($diff < $min_diff) ? 1 : 0}")
    if [ "$is_smaller" = "1" ]; then
      min_diff=$diff
      current_index=$i
    fi
  done

  # Calculate new index
  if [ "$DIRECTION" = "up" ]; then
    new_index=$((current_index + 1))
    if [ $new_index -ge ${#VALID_SCALES[@]} ]; then
      new_index=$((${#VALID_SCALES[@]} - 1))
      echo "Already at maximum scale"
    fi
  else
    new_index=$((current_index - 1))
    if [ $new_index -lt 0 ]; then
      new_index=0
      echo "Already at minimum scale"
    fi
  fi

  target_scale="${VALID_SCALES[$new_index]}"
  apply_monitor_scale "$MONITOR_INFO" "$target_scale" ""
fi

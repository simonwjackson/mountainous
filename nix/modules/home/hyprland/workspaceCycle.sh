#!/usr/bin/env bash

# Get all monitors and their active workspaces
monitors=$(hyprctl monitors -j)
monitor_count=$(echo "$monitors" | jq 'length')

# Ensure we have at least 2 monitors
if [ "$monitor_count" -lt 2 ]; then
    echo "Not enough monitors to cycle workspaces"
    exit 1
fi

# Extract data into simple arrays
declare -a monitor_names
declare -a active_workspaces

# Parse monitor data
for i in $(seq 0 $(($monitor_count - 1))); do
    monitor_names+=("$(echo "$monitors" | jq -r ".[$i].name")")
    active_workspaces+=("$(echo "$monitors" | jq -r ".[$i].activeWorkspace.id")")
done

# Create array of target monitors for each workspace
declare -a target_monitors
for i in $(seq 0 $(($monitor_count - 1))); do
    next_idx=$(( (i + 1) % monitor_count ))
    target_monitors+=("${monitor_names[$next_idx]}")
done

# Move all workspaces to their target monitors
for i in $(seq 0 $(($monitor_count - 1))); do
    hyprctl dispatch moveworkspacetomonitor ${active_workspaces[$i]} ${target_monitors[$i]}
done

# Focus each monitor on its new workspace
for i in $(seq 0 $(($monitor_count - 1))); do
    # Calculate which workspace is now on this monitor
    prev_idx=$(( (i - 1 + monitor_count) % monitor_count ))
    workspace=${active_workspaces[$prev_idx]}
    
    hyprctl dispatch focusmonitor ${monitor_names[$i]}
    hyprctl dispatch workspace $workspace
done

echo "Workspaces cycled forward successfully"

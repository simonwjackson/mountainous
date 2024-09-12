set -euo pipefail

# Function to get the current paused state of a share
get_paused_state() {
  local share="$1"
  syncthing cli config folders "$share" paused get | jq -r
}

# Function to set the paused state of a share
set_paused_state() {
  local share="$1"
  local state="$2"
  syncthing cli config folders "$share" paused set "$state"
}

# Function to toggle the paused state of a share
toggle_share() {
  local share="$1"
  local current_state
  current_state=$(get_paused_state "$share")
  if [ "$current_state" = "true" ]; then
    set_paused_state "$share" false
    echo "Unpaused share: $share"
  else
    set_paused_state "$share" true
    echo "Paused share: $share"
  fi
}

# Main script
if [ $# -lt 2 ]; then
  echo "Usage: $0 <action> <share1> [<share2> ...]"
  echo "Actions: pause, unpause, toggle"
  exit 1
fi

action="$1"
shift

case "$action" in
pause)
  for share in "$@"; do
    set_paused_state "$share" true
    echo "Paused share: $share"
  done
  ;;
unpause)
  for share in "$@"; do
    set_paused_state "$share" false
    echo "Unpaused share: $share"
  done
  ;;
toggle)
  for share in "$@"; do
    toggle_share "$share"
  done
  ;;
*)
  echo "Invalid action: $action"
  echo "Valid actions are: pause, unpause, toggle"
  exit 1
  ;;
esac

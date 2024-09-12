#!/usr/bin/env bash

# Function to check if a value is in an array
contains_element() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# Usage instructions using heredoc
usage() {
  cat <<EOF
Usage: $0 --execute <command> [--execute <command>...] [--help] [networks...]

This script checks for metered network connections and executes the specified
command(s) with the result.

Options:
  --execute <command>  The command(s) to execute with the metered status
                       Can be specified multiple times
  --help               Show this help message and exit

Arguments:
  networks             Optional list of network names to consider as metered

Environment Variables:
  EXECUTE              Comma-separated list of commands to execute

Example:
  $0 --execute "echo 'Metered:'" --execute "notify-send 'Network Status'" "My Home WiFi" "Coffee Shop WiFi"

  # Or using environment variables:
  EXECUTE="echo 'Metered:',notify-send 'Network Status'" $0 "My Home WiFi" "Coffee Shop WiFi"

EOF
}

# Parse command line arguments
execute_commands=()
networks=()

# Add commands from EXECUTE environment variable
if [ -n "${EXECUTE:-}" ]; then
  IFS=',' read -ra ENV_COMMANDS <<<"$EXECUTE"
  for cmd in "${ENV_COMMANDS[@]}"; do
    execute_commands+=("$cmd")
  done
fi

while [[ $# -gt 0 ]]; do
  case $1 in
  --help)
    usage
    exit 0
    ;;
  --execute)
    if [[ -n $2 ]]; then
      execute_commands+=("$2")
      shift 2
    else
      echo "Error: --execute requires a command argument"
      usage
      exit 1
    fi
    ;;
  *)
    networks+=("$1")
    shift
    ;;
  esac
done

# Check if at least one execute command is set
if [ ${#execute_commands[@]} -eq 0 ]; then
  echo "Error: At least one --execute command or EXECUTE environment variable is required."
  usage
  exit 1
fi

connections=$(nmcli -t -f NAME connection show --active)
is_metered=false

# Loop through each connection to check if any are metered
while IFS= read -r connection; do
  echo "Checking connection: $connection"

  # Check if the connection is in the list of additional metered networks
  if contains_element "$connection" "${networks[@]}"; then
    echo "Connection $connection is in the list of additional metered networks."
    is_metered=true
    break
  fi

  if nmcli connection show "$connection" | grep -q 'metered:.*yes'; then
    echo "Metered connection found: $connection"
    is_metered=true
  fi

  # Check if the connection is marked as metered by NetworkManager
  metered_status=$(
    nmcli connection show "$connection" |
      grep metered |
      grep -q yes && echo "yes" || echo "no"
  )

  if [ "$metered_status" = "yes" ]; then
    echo "Metered connection found: $connection"
    is_metered=true
  fi
done <<<"$connections"

if [ "$is_metered" = true ]; then
  echo "At least one metered connection found."
  for cmd in "${execute_commands[@]}"; do
    $cmd true
  done
else
  echo "No metered connections found."
  for cmd in "${execute_commands[@]}"; do
    $cmd false
  done
fi

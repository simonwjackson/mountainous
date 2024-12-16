#!/usr/bin/env bash

# HACK:
export XDG_RUNTIME_DIR="/run/user/1000"
HYPRLAND_INSTANCE_SIGNATURE=$(find "$XDG_RUNTIME_DIR/hypr/" -maxdepth 1 -type d | grep -v "^$XDG_RUNTIME_DIR/hypr/$" | awk -F'/' '{print $NF}')
export HYPRLAND_INSTANCE_SIGNATURE

PORT="${PORT:-9876}"
RESPONSE_OK="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n"
RESPONSE_BAD_REQUEST="HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\n\r\n"

handle_request() {
  local method="$1"
  local path="$2"
  local query_string="$3"

  case "$method" in
  "GET")
    # Extract the command from the path by removing the /api/ prefix
    local hyprctl_cmd=${path#/api/}
    hyprctl_cmd=$(echo "$hyprctl_cmd" | tr '/' ' ' | sed 's/+/ /g' | sed 's/%20/ /g' | sed -e 's/\^#/%23/g' -e 's/%23/#/g')

    # output=$(echo hyprctl "$hyprctl_cmd")

    echo -en "$RESPONSE_OK"
    # Execute hyprctl command and capture output
    output=$(hyprctl "$hyprctl_cmd" 2>&1)
    exit_code=$?

    # Check if the output is valid JSON
    if echo "$output" | jq -e . >/dev/null 2>&1; then
      # If it's already JSON, pass it through
      echo "$output"
    else
      # If it's not JSON, wrap it in a JSON object
      echo "{\"output\": \"$output\", \"exit_code\": $exit_code}"
    fi
    ;;
  *)
    echo -en "$RESPONSE_BAD_REQUEST"
    echo '{"error": "Method not supported"}'
    ;;
  esac
}

main() {
  echo "Starting Hyprland Control server on port $PORT..."
  socat TCP-LISTEN:"$PORT",reuseaddr,fork EXEC:"$0 handle",pty,raw,echo=0
}

if [ "${1:-}" = "handle" ]; then
  read -r request_line
  method=$(echo "$request_line" | cut -d' ' -f1)
  request=$(echo "$request_line" | cut -d' ' -f2)
  path=$(echo "$request" | cut -d'?' -f1)
  query_string=$(echo "$request" | cut -s -d'?' -f2)
  handle_request "$method" "$path" "$query_string"
else
  main
fi

#!/usr/bin/env bash
# codexbar-claude: Single metric for Claude usage (bar label)
# Shows the tightest constraint with color coding

set -euo pipefail

AUTH_FILE="${PI_AUTH_FILE:-$HOME/.pi/agent/auth.json}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/codexbar"
CACHE_FILE="$CACHE_DIR/claude-usage.json"
CACHE_MAX_AGE=600  # 10 minutes: serve cached data if fetch fails

mkdir -p "$CACHE_DIR"

use_cache() {
  if [[ -f "$CACHE_FILE" ]]; then
    local age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if (( age < CACHE_MAX_AGE )); then
      USAGE=$(cat "$CACHE_FILE")
      return 0
    fi
  fi
  return 1
}

if [[ ! -f "$AUTH_FILE" ]]; then
  echo '<span color="#f38ba8">C:--</span>'
  exit 0
fi

CLAUDE_TOKEN=$(jq -r '.anthropic.access // empty' "$AUTH_FILE" 2>/dev/null || true)
CLAUDE_EXPIRES=$(jq -r '.anthropic.expires // empty' "$AUTH_FILE" 2>/dev/null || true)

if [[ -z "$CLAUDE_TOKEN" ]]; then
  echo '<span color="#6c7086">C:--</span>'
  exit 0
fi

NOW_MS=$(($(date +%s) * 1000))
if [[ -n "$CLAUDE_EXPIRES" ]] && (( CLAUDE_EXPIRES < NOW_MS )); then
  echo '<span color="#f38ba8">C:exp</span>'
  exit 0
fi

USAGE=$(curl -sf --max-time 15 \
  --retry 3 --retry-delay 2 --retry-max-time 30 \
  -H "Authorization: Bearer $CLAUDE_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "User-Agent: claude-code/2.1.0" \
  "https://api.anthropic.com/api/oauth/usage" 2>/dev/null || true)

FROM_CACHE=false

if [[ -z "$USAGE" ]]; then
  if use_cache; then
    FROM_CACHE=true
  else
    echo '<span color="#f38ba8">C:⚡</span>'
    exit 0
  fi
fi

ERROR_TYPE=$(echo "$USAGE" | jq -r '.type // empty' 2>/dev/null || true)
if [[ "$ERROR_TYPE" == "error" ]]; then
  if use_cache; then
    FROM_CACHE=true
  else
    echo '<span color="#f38ba8">C:err</span>'
    exit 0
  fi
fi

# Cache successful fresh response
if [[ "$FROM_CACHE" == "false" ]]; then
  echo "$USAGE" > "$CACHE_FILE"
fi

echo "$USAGE" | jq -r '
  # Collect all utilization values, find the tightest constraint
  [
    .five_hour.utilization,
    .seven_day.utilization,
    .seven_day_sonnet.utilization,
    .seven_day_opus.utilization
  ] | map(select(. != null)) |

  if length == 0 then
    "<span color=\"#f38ba8\">C:--</span>"
  else
    (map(100 - . | round) | min) as $lowest |
    if $lowest <= 10 then
      "<span color=\"#f38ba8\">C:\($lowest)%</span>"
    elif $lowest <= 30 then
      "<span color=\"#fab387\">C:\($lowest)%</span>"
    else
      "<span color=\"#a6e3a1\">C:\($lowest)%</span>"
    end
  end
' 2>/dev/null || echo '<span color="#f38ba8">C:err</span>'

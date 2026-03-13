#!/usr/bin/env bash
# codexbar-claude: Single metric for Claude usage (bar label)
# Shows the tightest constraint with color coding

set -euo pipefail

AUTH_FILE="${PI_AUTH_FILE:-$HOME/.pi/agent/auth.json}"

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

USAGE=$(curl -sf --max-time 10 \
  -H "Authorization: Bearer $CLAUDE_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "User-Agent: claude-code/2.1.0" \
  "https://api.anthropic.com/api/oauth/usage" 2>/dev/null || true)

if [[ -z "$USAGE" ]]; then
  echo '<span color="#f38ba8">C:⚡</span>'
  exit 0
fi

ERROR_TYPE=$(echo "$USAGE" | jq -r '.type // empty' 2>/dev/null || true)
if [[ "$ERROR_TYPE" == "error" ]]; then
  echo '<span color="#f38ba8">C:err</span>'
  exit 0
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

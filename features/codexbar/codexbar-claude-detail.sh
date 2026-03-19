#!/usr/bin/env bash
# codexbar-claude-detail: Detailed Claude usage for popup

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
  echo "No auth file found"
  exit 0
fi

CLAUDE_TOKEN=$(jq -r '.anthropic.access // empty' "$AUTH_FILE" 2>/dev/null || true)

if [[ -z "$CLAUDE_TOKEN" ]]; then
  echo "No Claude credentials"
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

CACHED=false

if [[ -z "$USAGE" ]]; then
  if use_cache; then
    CACHED=true
  else
    echo "Failed to fetch usage"
    exit 0
  fi
fi

ERROR_TYPE=$(echo "$USAGE" | jq -r '.type // empty' 2>/dev/null || true)
if [[ "$ERROR_TYPE" == "error" ]]; then
  if use_cache; then
    CACHED=true
  else
    echo "$USAGE" | jq -r '.error.message // "API error"' 2>/dev/null
    exit 0
  fi
fi

# Cache successful response
if [[ "$CACHED" == "false" ]]; then
  echo "$USAGE" > "$CACHE_FILE"
fi

export CODEXBAR_CACHED="$CACHED"

echo "$USAGE" | jq -r '
  def color_pct:
    (100 - . | round) as $rem |
    if $rem <= 10 then "#f38ba8"
    elif $rem <= 30 then "#fab387"
    else "#a6e3a1"
    end;

  def fmt_window(name):
    if . then
      .utilization as $u |
      .resets_at as $r |
      (100 - $u | round) as $rem |
      ($u | color_pct) as $col |

      # Reset time
      (if $r then
        ($r | split("+")[0] | split(".")[0] + "Z" | fromdateiso8601) as $reset |
        (now | floor) as $now |
        ($reset - $now) as $diff |
        if $diff > 0 then
          ($diff / 3600 | floor) as $h |
          (($diff % 3600) / 60 | floor) as $m |
          if $h > 24 then
            "\($h / 24 | floor)d \($h % 24)h"
          elif $h > 0 then
            "\($h)h \($m)m"
          else
            "\($m)m"
          end
        else "now"
        end
      else "—"
      end) as $time |

      "<span color=\"#cdd6f4\">\(name)</span>  <span color=\"\($col)\">\($rem)%</span>  <span color=\"#6c7086\">↻ \($time)</span>"
    else empty
    end;

  [
    "<span color=\"#89b4fa\" font_weight=\"bold\">Claude</span>" +
    (if $ENV.CODEXBAR_CACHED == "true" then "  <span color=\"#6c7086\">(cached)</span>" else "" end),
    "",
    (.five_hour | fmt_window("Session")),
    (.seven_day | fmt_window("Weekly ")),
    (.seven_day_sonnet | fmt_window("Sonnet ")),
    (.seven_day_opus | fmt_window("Opus   ")),
    (if .extra_usage.is_enabled == true then
      "\n<span color=\"#cdd6f4\">Credits</span>  <span color=\"#a6e3a1\">\(.extra_usage.used_credits // 0 | tostring)</span> / <span color=\"#6c7086\">\(.extra_usage.monthly_limit // "∞" | tostring)</span>"
    else empty
    end)
  ] | join("\n")
' 2>/dev/null || echo "Parse error"

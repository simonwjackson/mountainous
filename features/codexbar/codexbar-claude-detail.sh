#!/usr/bin/env bash
# codexbar-claude-detail: Detailed Claude usage for popup

set -euo pipefail

AUTH_FILE="${PI_AUTH_FILE:-$HOME/.pi/agent/auth.json}"

if [[ ! -f "$AUTH_FILE" ]]; then
  echo "No auth file found"
  exit 0
fi

CLAUDE_TOKEN=$(jq -r '.anthropic.access // empty' "$AUTH_FILE" 2>/dev/null || true)

if [[ -z "$CLAUDE_TOKEN" ]]; then
  echo "No Claude credentials"
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
  echo "Failed to fetch usage"
  exit 0
fi

ERROR_TYPE=$(echo "$USAGE" | jq -r '.type // empty' 2>/dev/null || true)
if [[ "$ERROR_TYPE" == "error" ]]; then
  echo "$USAGE" | jq -r '.error.message // "API error"' 2>/dev/null
  exit 0
fi

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
    "<span color=\"#89b4fa\" font_weight=\"bold\">Claude</span>",
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

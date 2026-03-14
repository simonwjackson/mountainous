#!/usr/bin/env bash
# codexbar-codex-detail: Detailed Codex usage for popup

set -euo pipefail

AUTH_FILE="${PI_AUTH_FILE:-$HOME/.pi/agent/auth.json}"

if [[ ! -f "$AUTH_FILE" ]]; then
  echo "No auth file found"
  exit 0
fi

CODEX_TOKEN=$(jq -r '."openai-codex".access // empty' "$AUTH_FILE" 2>/dev/null || true)
CODEX_ACCOUNT=$(jq -r '."openai-codex".accountId // empty' "$AUTH_FILE" 2>/dev/null || true)

if [[ -z "$CODEX_TOKEN" ]]; then
  echo "No Codex credentials"
  exit 0
fi

HEADERS=(-H "Authorization: Bearer $CODEX_TOKEN"
         -H "Accept: application/json"
         -H "User-Agent: CodexBar")
[[ -n "$CODEX_ACCOUNT" ]] && HEADERS+=(-H "ChatGPT-Account-Id: $CODEX_ACCOUNT")

USAGE=$(curl -sf --max-time 10 \
  "${HEADERS[@]}" \
  "https://chatgpt.com/backend-api/wham/usage" 2>/dev/null || true)

if [[ -z "$USAGE" ]]; then
  echo "Failed to fetch usage"
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
      .used_percent as $u |
      .reset_at as $r |
      (100 - $u | round) as $rem |
      ($u | color_pct) as $col |

      (if $r then
        (now | floor) as $now |
        ($r - $now) as $diff |
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

  .rate_limit as $rl |
  .plan_type as $plan |
  .email as $email |
  .credits as $credits |

  [
    "<span color=\"#f9e2af\" font_weight=\"bold\">Codex</span>" +
    (if $plan then "  <span color=\"#6c7086\">\($plan)</span>" else "" end),
    "",
    ($rl.primary_window | fmt_window("Session")),
    ($rl.secondary_window | fmt_window("Weekly ")),
    (if .additional_rate_limits and (.additional_rate_limits | length) > 0 then
      "",
      (.additional_rate_limits[] |
        "<span color=\"#6c7086\">\(.limit_name // .metered_feature)</span>",
        (.rate_limit.primary_window | fmt_window("  5hr  ")),
        (.rate_limit.secondary_window | fmt_window("  week "))
      )
    else empty
    end),
    (if $credits.has_credits then
      "\n<span color=\"#cdd6f4\">Credits</span>  <span color=\"#a6e3a1\">\($credits.balance // "0")</span>"
    else empty
    end)
  ] | join("\n")
' 2>/dev/null || echo "Parse error"

#!/usr/bin/env bash
# codexbar-codex: Single metric for Codex usage (bar label)
# Shows the tightest constraint with color coding

set -euo pipefail

AUTH_FILE="${PI_AUTH_FILE:-$HOME/.pi/agent/auth.json}"

if [[ ! -f "$AUTH_FILE" ]]; then
  echo '<span color="#f38ba8">X:--</span>'
  exit 0
fi

CODEX_TOKEN=$(jq -r '."openai-codex".access // empty' "$AUTH_FILE" 2>/dev/null || true)
CODEX_ACCOUNT=$(jq -r '."openai-codex".accountId // empty' "$AUTH_FILE" 2>/dev/null || true)
CODEX_EXPIRES=$(jq -r '."openai-codex".expires // empty' "$AUTH_FILE" 2>/dev/null || true)

if [[ -z "$CODEX_TOKEN" ]]; then
  echo '<span color="#6c7086">X:--</span>'
  exit 0
fi

NOW_MS=$(($(date +%s) * 1000))
if [[ -n "$CODEX_EXPIRES" ]] && (( CODEX_EXPIRES < NOW_MS )); then
  echo '<span color="#f38ba8">X:exp</span>'
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
  echo '<span color="#f38ba8">X:⚡</span>'
  exit 0
fi

echo "$USAGE" | jq -r '
  .rate_limit as $rl |

  if $rl then
    [
      $rl.primary_window.used_percent,
      $rl.secondary_window.used_percent
    ] | map(select(. != null)) |

    if length == 0 then
      "<span color=\"#f38ba8\">X:--</span>"
    else
      (map(100 - . | round) | min) as $lowest |
      if $lowest <= 10 then
        "<span color=\"#f38ba8\">X:\($lowest)%</span>"
      elif $lowest <= 30 then
        "<span color=\"#fab387\">X:\($lowest)%</span>"
      else
        "<span color=\"#a6e3a1\">X:\($lowest)%</span>"
      end
    end
  else
    "<span color=\"#f38ba8\">X:--</span>"
  end
' 2>/dev/null || echo '<span color="#f38ba8">X:err</span>'

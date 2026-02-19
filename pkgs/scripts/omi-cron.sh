#!/usr/bin/env bash

# Omi Cron — runs pipeline + notify, sends to Telegram directly.
# No LLM needed. Just shell.

set -euo pipefail

TELEGRAM_BOT_TOKEN_FILE="${TELEGRAM_BOT_TOKEN_FILE:-/run/agenix/telegram-bot-token}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-6371873126}"

# Run pipeline (sync + classify)
omi-pipeline

# Check for pending notifications
OUTPUT="$(omi-notify)"

# If empty, done
if [[ "$OUTPUT" == "EMPTY" ]]; then
  exit 0
fi

# Strip the "PENDING:N" header and "---" separator, keep the formatted content
MESSAGE="$(echo "$OUTPUT" | sed '1,/^---$/d' | sed '/^$/N;/^\n$/d')"

if [[ -z "$MESSAGE" ]]; then
  exit 0
fi

# Send to Telegram
if [[ -r "$TELEGRAM_BOT_TOKEN_FILE" ]]; then
  BOT_TOKEN="$(cat "$TELEGRAM_BOT_TOKEN_FILE")"
else
  echo "ERROR: Cannot read Telegram bot token from $TELEGRAM_BOT_TOKEN_FILE"
  exit 1
fi

curl -sf -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="$TELEGRAM_CHAT_ID" \
  -d parse_mode="Markdown" \
  --data-urlencode text="📬 *Omi Update*

${MESSAGE}" > /dev/null

echo "Notification sent to Telegram."

#!/usr/bin/env bash

# Omi Notification Drain
# Reads .pending-notifications.jsonl, formats a summary, outputs it, then clears the queue.
# Designed to be called by a cron agentTurn that forwards to Simon.


NOTIFY_FILE="${OMI_DIR:-$HOME/omi}/.pending-notifications.jsonl"

if [[ ! -f "$NOTIFY_FILE" ]] || [[ ! -s "$NOTIFY_FILE" ]]; then
  echo "EMPTY"
  exit 0
fi

# Count items
TOTAL="$(wc -l < "$NOTIFY_FILE")"
echo "PENDING:$TOTAL"
echo "---"

# Output each notification as formatted text
while IFS= read -r line; do
  TITLE="$(echo "$line" | jq -r '.title')"
  STALE="$(echo "$line" | jq -r '.stale_hours')"
  ITEMS="$(echo "$line" | jq -r '.items // [] | map(.type + ": " + .text + (if .urgency == "high" then " [URGENT]" else "" end)) | join("\n")')"

  echo "📌 $TITLE"
  if [[ "$STALE" -gt 2 ]]; then
    echo "  ⏰ (from ${STALE}h ago)"
  fi
  echo "$ITEMS" | sed 's/^/  /'
  echo ""
done < "$NOTIFY_FILE"

# Clear the queue
true > "$NOTIFY_FILE"

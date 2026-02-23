#!/usr/bin/env bash

# Omi Pipeline v3
# Sync from Omi API → write one transcript file per day
# No classification, no Groq, no notifications. Just transcripts.

set -euo pipefail

OMI_DIR="${OMI_DIR:-$HOME/omi}"
TRANSCRIPTS_DIR="$OMI_DIR/transcripts"
STATE_FILE="$OMI_DIR/.pipeline-state.json"
LOCK_FILE="$OMI_DIR/.pipeline.lock"
OMI_API_KEY_FILE="${OMI_API_KEY_FILE:-/run/agenix/omi-api-key}"
OMI_API_BASE="https://api.omi.me/v1/dev"
BATCH_SIZE=50

# --- Lockfile ---
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  echo "Another pipeline run is in progress, skipping."
  exit 0
fi
trap 'rm -f "$LOCK_FILE"' EXIT

# --- Init ---
mkdir -p "$TRANSCRIPTS_DIR"

OMI_API_KEY="$(cat "$OMI_API_KEY_FILE")"

if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"last_api_sync":"","conversations":{}}' > "$STATE_FILE"
fi

LAST_SYNC="$(jq -r '.last_api_sync // empty' "$STATE_FILE")"

# --- Fetch from Omi API ---
echo "=== Omi Pipeline v3 ==="
date -u +%Y-%m-%dT%H:%M:%SZ

OFFSET=0
ALL_CONVERSATIONS="[]"

while true; do
  PARAMS="limit=$BATCH_SIZE&offset=$OFFSET&include_transcript=true"
  if [[ -n "$LAST_SYNC" ]]; then
    PARAMS="$PARAMS&start_date=$LAST_SYNC"
  fi

  RESPONSE="$(curl -sf -H "Authorization: Bearer $OMI_API_KEY" \
    "$OMI_API_BASE/user/conversations?$PARAMS" 2>/dev/null)" || {
    echo "ERROR: Omi API request failed"
    exit 1
  }

  COUNT="$(echo "$RESPONSE" | jq 'length')"
  echo "Fetched $COUNT conversations (offset $OFFSET)"

  [[ "$COUNT" -eq 0 ]] && break

  ALL_CONVERSATIONS="$(echo "$ALL_CONVERSATIONS $RESPONSE" | jq -s 'add')"
  OFFSET=$((OFFSET + BATCH_SIZE))
  [[ "$COUNT" -lt "$BATCH_SIZE" ]] && break
done

TOTAL="$(echo "$ALL_CONVERSATIONS" | jq 'length')"
echo "Total from API: $TOTAL"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "Nothing new."
  exit 0
fi

# --- Group by date (MST = UTC-7) and write daily files ---
# Get all unique dates, build one file per day

# Track which conversation IDs we've seen
declare -A SEEN_IDS

echo "$ALL_CONVERSATIONS" | jq -c '.[]' | while IFS= read -r conv; do
  ID="$(echo "$conv" | jq -r '.id')"
  STARTED="$(echo "$conv" | jq -r '.started_at')"
  FINISHED="$(echo "$conv" | jq -r '.finished_at // empty')"
  TITLE="$(echo "$conv" | jq -r '.structured.title // "Untitled"')"
  OVERVIEW="$(echo "$conv" | jq -r '.structured.overview // ""')"
  EMOJI="$(echo "$conv" | jq -r '.structured.emoji // ""')"

  # Skip in-progress conversations
  if [[ -z "$FINISHED" ]]; then
    echo "  ⏳ $ID — still in progress, skipping"
    continue
  fi

  # Skip if already processed and finished_at hasn't changed
  KNOWN_FINISHED="$(jq -r --arg id "$ID" '.conversations[$id].finished_at // empty' "$STATE_FILE")"
  if [[ "$KNOWN_FINISHED" == "$FINISHED" ]]; then
    continue
  fi

  # Convert started_at to MST date for grouping
  # MST = UTC-7
  DATE_MST="$(TZ=America/Denver date -d "$STARTED" +%Y-%m-%d 2>/dev/null || echo "$STARTED" | cut -c1-10)"
  TIME_MST="$(TZ=America/Denver date -d "$STARTED" +%H:%M 2>/dev/null || echo "$STARTED" | cut -c12-16)"

  DAILY_FILE="$TRANSCRIPTS_DIR/${DATE_MST}.md"

  # Build transcript text
  TRANSCRIPT="$(echo "$conv" | jq -r '
    if .transcript_segments != null and (.transcript_segments | length) > 0 then
      .transcript_segments | map(
        "**" + (.speaker_name // "Unknown") + ":** " + .text
      ) | join("\n\n")
    else
      "*No transcript segments available*"
    end
  ')"

  # If this conversation was previously written (updated finished_at), we need to
  # remove the old entry. Use the ID marker to find and remove it.
  if [[ -f "$DAILY_FILE" ]]; then
    # Remove old entry for this ID if it exists (between markers)
    sed -i "/<!-- omi:${ID} -->/,/<!-- \/omi:${ID} -->/d" "$DAILY_FILE"
  fi

  # Append to daily file
  if [[ ! -f "$DAILY_FILE" ]]; then
    echo "# ${DATE_MST}" > "$DAILY_FILE"
    echo "" >> "$DAILY_FILE"
  fi

  {
    echo "<!-- omi:${ID} -->"
    echo "## ${EMOJI} ${TITLE} (${TIME_MST})"
    echo ""
    if [[ -n "$OVERVIEW" ]]; then
      echo "> ${OVERVIEW}"
      echo ""
    fi
    echo "$TRANSCRIPT"
    echo ""
    echo "<!-- /omi:${ID} -->"
    echo ""
  } >> "$DAILY_FILE"

  echo "  ✅ ${DATE_MST} — ${TITLE}"

  # Update state
  TMP="$(mktemp)"
  jq --arg id "$ID" --arg fin "$FINISHED" --arg date "$DATE_MST" \
    '.conversations[$id] = {finished_at: $fin, date: $date}' \
    "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
done

# --- Update last_api_sync ---
NEWEST="$(echo "$ALL_CONVERSATIONS" | jq -r '[.[].created_at] | sort | last // empty')"
if [[ -n "$NEWEST" ]]; then
  TMP="$(mktemp)"
  jq --arg ts "$NEWEST" '.last_api_sync = $ts' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
  echo "Updated last_api_sync: $NEWEST"
fi

echo "=== Pipeline complete ==="

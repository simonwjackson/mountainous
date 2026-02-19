
# Omi Transcript Sync
# Pulls conversations from Omi API and saves as markdown files
# Tracks last sync to avoid re-downloading


OMI_DIR="${OMI_DIR:-$HOME/omi}"
TRANSCRIPTS_DIR="$OMI_DIR/transcripts"
STATE_FILE="$OMI_DIR/.sync-state.json"
API_KEY_FILE="$HOME/.secrets/omi-api-key"
API_BASE="https://api.omi.me/v1/dev"
BATCH_SIZE=50

mkdir -p "$TRANSCRIPTS_DIR"

if [[ ! -f "$API_KEY_FILE" ]]; then
  echo "ERROR: API key not found at $API_KEY_FILE" >&2
  exit 1
fi

API_KEY="$(cat "$API_KEY_FILE")"

# Get last sync timestamp
LAST_SYNC=""
if [[ -f "$STATE_FILE" ]]; then
  LAST_SYNC="$(jq -r '.last_sync // empty' "$STATE_FILE" 2>/dev/null || true)"
fi

# Paginated fetch
echo "Syncing Omi conversations..."
[[ -n "$LAST_SYNC" ]] && echo "  Since: $LAST_SYNC" || echo "  Full sync (first run)"

OFFSET=0
TOTAL_FETCHED=0
NEWEST_TS=""

while true; do
  PARAMS="limit=$BATCH_SIZE&offset=$OFFSET&include_transcript=true"
  if [[ -n "$LAST_SYNC" ]]; then
    PARAMS="$PARAMS&start_date=$LAST_SYNC"
  fi

  RESPONSE="$(curl -sf -H "Authorization: Bearer $API_KEY" "$API_BASE/user/conversations?$PARAMS")"
  COUNT="$(echo "$RESPONSE" | jq 'length')"
  echo "  Fetched: $COUNT (offset $OFFSET)"

  if [[ "$COUNT" -eq 0 ]]; then
    break
  fi

  TOTAL_FETCHED=$((TOTAL_FETCHED + COUNT))

NEWEST_TS=""
NEW_COUNT=0

echo "$RESPONSE" | jq -c '.[]' | while read -r conv; do
  ID="$(echo "$conv" | jq -r '.id')"
  CREATED="$(echo "$conv" | jq -r '.created_at')"
  STARTED="$(echo "$conv" | jq -r '.started_at')"
  FINISHED="$(echo "$conv" | jq -r '.finished_at')"
  TITLE="$(echo "$conv" | jq -r '.structured.title // "Untitled"')"
  OVERVIEW="$(echo "$conv" | jq -r '.structured.overview // ""')"
  EMOJI="$(echo "$conv" | jq -r '.structured.emoji // ""')"
  CATEGORY="$(echo "$conv" | jq -r '.structured.category // ""')"
  LANGUAGE="$(echo "$conv" | jq -r '.language // ""')"
  SOURCE="$(echo "$conv" | jq -r '.source // ""')"
  ADDRESS="$(echo "$conv" | jq -r '.geolocation.address // ""')"

  # Date prefix for filename
  DATE_PREFIX="$(echo "$STARTED" | cut -c1-10)"
  TIME_PREFIX="$(echo "$STARTED" | cut -c12-16 | tr -d ':')"
  SAFE_TITLE="$(echo "$TITLE" | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/--*/-/g; s/^-//; s/-$//' | cut -c1-60 | sed 's/.*/\L&/')"
  FILENAME="${DATE_PREFIX}-${TIME_PREFIX}-${SAFE_TITLE}.md"
  FILEPATH="$TRANSCRIPTS_DIR/$FILENAME"

  # Skip if already exists
  if [[ -f "$FILEPATH" ]]; then
    continue
  fi

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

  # Action items
  ACTION_ITEMS="$(echo "$conv" | jq -r '
    if .structured.action_items != null and (.structured.action_items | length) > 0 then
      .structured.action_items | map("- [ ] " + .description) | join("\n")
    else
      empty
    end
  ')"

  # Write markdown file
  {
    echo "---"
    echo "id: $ID"
    echo "title: \"$TITLE\""
    echo "date: $STARTED"
    echo "finished: $FINISHED"
    echo "category: $CATEGORY"
    echo "language: $LANGUAGE"
    echo "source: $SOURCE"
    [[ -n "$ADDRESS" ]] && echo "location: \"$ADDRESS\""
    echo "---"
    echo ""
    echo "# $EMOJI $TITLE"
    echo ""
    if [[ -n "$OVERVIEW" ]]; then
      echo "> $OVERVIEW"
      echo ""
    fi
    if [[ -n "$ACTION_ITEMS" ]]; then
      echo "## Action Items"
      echo ""
      echo "$ACTION_ITEMS"
      echo ""
    fi
    echo "## Transcript"
    echo ""
    echo "$TRANSCRIPT"
  } > "$FILEPATH"

  echo "  ✓ $FILENAME"
done

  # Track newest timestamp from this batch
  BATCH_NEWEST="$(echo "$RESPONSE" | jq -r '[.[].created_at] | sort | last')"
  if [[ -z "$NEWEST_TS" ]] || [[ "$BATCH_NEWEST" > "$NEWEST_TS" ]]; then
    NEWEST_TS="$BATCH_NEWEST"
  fi

  OFFSET=$((OFFSET + BATCH_SIZE))

  # Stop if we got fewer than batch size (last page)
  if [[ "$COUNT" -lt "$BATCH_SIZE" ]]; then
    break
  fi
done

if [[ "$TOTAL_FETCHED" -eq 0 ]]; then
  echo "  Nothing new."
  exit 0
fi

# Update sync state
if [[ -n "$NEWEST_TS" ]]; then
  echo "{\"last_sync\": \"$NEWEST_TS\", \"last_run\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"total\": $TOTAL_FETCHED}" > "$STATE_FILE"
fi

echo "Done. $TOTAL_FETCHED conversations synced to $TRANSCRIPTS_DIR"

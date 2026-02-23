#!/usr/bin/env bash

# Omi Pipeline v3
# Sync from Omi API → write one transcript file per day
# Optimized format for LLM consumption (minimal tokens)

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

# --- Process conversations into daily files ---

echo "$ALL_CONVERSATIONS" | jq -c '.[]' | while IFS= read -r conv; do
  ID="$(echo "$conv" | jq -r '.id')"
  STARTED="$(echo "$conv" | jq -r '.started_at')"
  FINISHED="$(echo "$conv" | jq -r '.finished_at // empty')"
  TITLE="$(echo "$conv" | jq -r '.structured.title // "Untitled"')"

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
  DATE_MST="$(TZ=America/Denver date -d "$STARTED" +%Y-%m-%d 2>/dev/null || echo "$STARTED" | cut -c1-10)"
  TIME_MST="$(TZ=America/Denver date -d "$STARTED" +%H:%M 2>/dev/null || echo "$STARTED" | cut -c12-16)"

  DAILY_FILE="$TRANSCRIPTS_DIR/${DATE_MST}.md"

  # Build optimized transcript:
  # - "User" → "Simon", named speakers keep name, unknown → S1/S2/etc
  # - Collapse consecutive same-speaker segments
  # - Single newlines between speaker changes
  TRANSCRIPT="$(echo "$conv" | jq -r '
    if .transcript_segments != null and (.transcript_segments | length) > 0 then
      # Build speaker label map: track unknown speaker counter
      # First pass: collect unique speaker_ids and their names
      (
        [.transcript_segments[] | {id: (.speaker_id // 0), name: (.speaker_name // "Unknown")}]
        | unique_by(.id)
        | to_entries
        | map(
            if .value.name == "User" then {key: (.value.id | tostring), value: "Simon"}
            elif .value.name != null and .value.name != "Unknown" and (.value.name | startswith("Speaker ") | not) then {key: (.value.id | tostring), value: .value.name}
            else {key: (.value.id | tostring), value: "S\(.key + 1)"}
            end
          )
        | from_entries
      ) as $labels |
      # Second pass: build transcript with collapsed consecutive segments
      (
        .transcript_segments
        | reduce .[] as $seg (
            {lines: [], last_speaker: null, last_text: ""};
            ($labels[($seg.speaker_id // 0 | tostring)] // "S?") as $label |
            if $label == .last_speaker then
              # Same speaker continues — append text
              .last_text += (" " + $seg.text)
            else
              # Speaker changed — flush previous
              (if .last_speaker != null then
                .lines += [.last_speaker + ": " + .last_text]
              else . end) |
              .last_speaker = $label |
              .last_text = $seg.text
            end
          )
        # Flush final speaker
        | if .last_speaker != null then .lines += [.last_speaker + ": " + .last_text] else . end
        | .lines | join("\n")
      )
    else
      "(no transcript)"
    end
  ')"

  # Remove old entry for this ID if daily file exists
  if [[ -f "$DAILY_FILE" ]]; then
    sed -i "/<!-- omi:${ID} -->/,/<!-- \/omi:${ID} -->/d" "$DAILY_FILE"
  fi

  # Create daily file header if new
  if [[ ! -f "$DAILY_FILE" ]]; then
    echo "# ${DATE_MST}" > "$DAILY_FILE"
  fi

  # Append conversation
  {
    echo "<!-- omi:${ID} -->"
    echo "## ${TITLE} | ${TIME_MST}"
    echo "$TRANSCRIPT"
    echo "<!-- /omi:${ID} -->"
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

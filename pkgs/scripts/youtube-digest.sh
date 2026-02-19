#!/usr/bin/env bash

# YouTube Daily Digest
# Checks followed channels for new uploads (last 48h), adds discovery searches,
# outputs a markdown digest to stdout and saves to file.
#
# Env: INVIDIOUS_URL (default http://127.0.0.1:3333)
#      INVIDIOUS_TOKEN_FILE (default /run/agenix/invidious-token)
#      CHANNELS_FILE (default ~/.openclaw/workspace/.secrets/invidious-channels.json)
#      PROFILE_FILE (default ~/.openclaw/workspace/memory/youtube-profile.md)
#      OUTPUT_DIR (default ~/.openclaw/workspace/memory/youtube)

set -euo pipefail

INVIDIOUS_URL="${INVIDIOUS_URL:-http://127.0.0.1:3333}"
INVIDIOUS_PUBLIC_URL="${INVIDIOUS_PUBLIC_URL:-https://youtube.hummingbird-lake.ts.net}"
INVIDIOUS_TOKEN_FILE="${INVIDIOUS_TOKEN_FILE:-/run/agenix/invidious-token}"
CHANNELS_FILE="${CHANNELS_FILE:-$HOME/.openclaw/workspace/.secrets/invidious-channels.json}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/.openclaw/workspace/memory/youtube}"
TODAY=$(date -u +%Y-%m-%d)
OUTPUT_FILE="$OUTPUT_DIR/$TODAY.md"
CUTOFF_SECS=$((48 * 3600))
NOW=$(date +%s)

mkdir -p "$OUTPUT_DIR"

TOKEN=""
if [[ -f "$INVIDIOUS_TOKEN_FILE" ]]; then
  TOKEN=$(cat "$INVIDIOUS_TOKEN_FILE")
fi

# Format duration from seconds
format_duration() {
  local secs=$1
  local h=$((secs / 3600))
  local m=$(( (secs % 3600) / 60 ))
  if [[ $h -gt 0 ]]; then
    printf "%dh%02dm" "$h" "$m"
  else
    printf "%dm" "$m"
  fi
}

# Fetch channel's latest videos, filter to last 48h
fetch_channel_new() {
  local channel_id=$1
  local channel_name=$2
  local response
  response=$(curl -sf "$INVIDIOUS_URL/api/v1/channels/$channel_id" 2>/dev/null) || return 0

  echo "$response" | jq -r --argjson cutoff "$((NOW - CUTOFF_SECS))" --arg name "$channel_name" \
    --arg base_url "$INVIDIOUS_URL" --arg pub_url "$INVIDIOUS_PUBLIC_URL" \
    '.latestVideos[]
     | select(.published > $cutoff and .lengthSeconds > 60)
     | "- **\(.title)** — \($name) · \(if .lengthSeconds >= 3600 then "\(.lengthSeconds / 3600 | floor)h\((.lengthSeconds % 3600 / 60) | floor)m" else "\((.lengthSeconds / 60) | floor)m" end) · [watch](\($pub_url)/watch?v=\(.videoId))"' \
    2>/dev/null
}

# Search for discovery content
search_videos() {
  local query=$1
  local response
  response=$(curl -sf "$INVIDIOUS_URL/api/v1/search?q=$(echo "$query" | sed 's/ /+/g')&sort_by=upload_date&type=video" 2>/dev/null) || return 0

  echo "$response" | jq -r --argjson cutoff "$((NOW - CUTOFF_SECS * 2))" \
    --arg base_url "$INVIDIOUS_URL" --arg pub_url "$INVIDIOUS_PUBLIC_URL" \
    '[.[] | select(.published > $cutoff and .lengthSeconds > 120)] | .[0:2][] |
     "- **\(.title)** — \(.author) · \(if .lengthSeconds >= 3600 then "\(.lengthSeconds / 3600 | floor)h\((.lengthSeconds % 3600 / 60) | floor)m" else "\((.lengthSeconds / 60) | floor)m" end) · [watch](\($pub_url)/watch?v=\(.videoId))"' \
    2>/dev/null
}

# Get watch history for dedup
WATCHED=""
if [[ -n "$TOKEN" ]]; then
  WATCHED=$(curl -sf -H "Authorization: Bearer $TOKEN" "$INVIDIOUS_URL/api/v1/auth/history" 2>/dev/null | jq -r '.[]' 2>/dev/null || echo "")
fi

# === Build digest ===
DIGEST="# YouTube Digest — $TODAY\n\n"

# New uploads from followed channels
DIGEST+="## 🆕 New Uploads (last 48h)\n\n"
NEW_COUNT=0

if [[ -f "$CHANNELS_FILE" ]]; then
  while IFS= read -r line; do
    channel_id=$(echo "$line" | jq -r '.id')
    channel_name=$(echo "$line" | jq -r '.name')
    results=$(fetch_channel_new "$channel_id" "$channel_name")
    if [[ -n "$results" ]]; then
      # Filter out watched videos
      while IFS= read -r video_line; do
        video_id=$(echo "$video_line" | grep -oP 'v=\K[^)]+' || echo "")
        if [[ -z "$WATCHED" ]] || ! echo "$WATCHED" | grep -q "$video_id"; then
          DIGEST+="$video_line\n"
          NEW_COUNT=$((NEW_COUNT + 1))
        fi
      done <<< "$results"
    fi
  done < <(jq -c '.top_channels[]' "$CHANNELS_FILE")
fi

if [[ $NEW_COUNT -eq 0 ]]; then
  DIGEST+="_No new uploads from followed channels._\n"
fi

# Discovery searches
DIGEST+="\n## 🔍 Discovery\n\n"

SEARCH_QUERIES=(
  "AI coding agent tools 2026"
  "epistemology philosophy debate"
  "indie game design devlog"
)

for query in "${SEARCH_QUERIES[@]}"; do
  results=$(search_videos "$query")
  if [[ -n "$results" ]]; then
    DIGEST+="**$query:**\n$results\n\n"
  fi
done

# Save and output
echo -e "$DIGEST" > "$OUTPUT_FILE"
echo -e "$DIGEST"
echo ""
echo "Saved to: $OUTPUT_FILE"

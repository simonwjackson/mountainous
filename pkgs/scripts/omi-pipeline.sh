#!/usr/bin/env bash

# Omi Pipeline v2
# Sync → Groq classify/extract → write memory → notify if actionable
# Runs every 2 minutes, 7am-midnight MST


OMI_DIR="${OMI_DIR:-$HOME/omi}"
TRANSCRIPTS_DIR="$OMI_DIR/transcripts"
STATE_FILE="$OMI_DIR/.pipeline-state.json"
LOCK_FILE="$OMI_DIR/.pipeline.lock"
MEMORY_DIR="$HOME/.openclaw/workspace/memory"
OMI_API_KEY_FILE="${OMI_API_KEY_FILE:-/run/agenix/omi-api-key}"
GROQ_API_KEY_FILE="/run/agenix/groq-env"
OMI_API_BASE="https://api.omi.me/v1/dev"
GROQ_API_BASE="https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL="llama-3.1-8b-instant"
BATCH_SIZE=50

# --- Lockfile (prevent concurrent runs) ---
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  echo "Another pipeline run is in progress, skipping."
  exit 0
fi
trap 'rm -f "$LOCK_FILE"' EXIT

# --- Init ---
mkdir -p "$TRANSCRIPTS_DIR" "$MEMORY_DIR"

OMI_API_KEY="$(cat "$OMI_API_KEY_FILE")"

GROQ_AVAILABLE=false
if [[ -r "$GROQ_API_KEY_FILE" ]]; then
  GROQ_API_KEY="$(grep -oP 'GROQ_API_KEY=\K.*' "$GROQ_API_KEY_FILE" 2>/dev/null || cat "$GROQ_API_KEY_FILE")"
  [[ -n "$GROQ_API_KEY" ]] && GROQ_AVAILABLE=true
fi

# Init state file
if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"last_api_sync":"","conversations":{}}' > "$STATE_FILE"
fi

LAST_SYNC="$(jq -r '.last_api_sync // empty' "$STATE_FILE")"

# --- Fetch from Omi API ---
echo "=== Omi Pipeline v2 ==="
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | Groq: $GROQ_AVAILABLE"

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

# --- Process each conversation ---
NEW_COUNT=0
UPDATED_COUNT=0
ACTIONABLE_ITEMS=()

echo "$ALL_CONVERSATIONS" | jq -c '.[]' | while IFS= read -r conv; do
  ID="$(echo "$conv" | jq -r '.id')"
  CREATED="$(echo "$conv" | jq -r '.created_at')"
  STARTED="$(echo "$conv" | jq -r '.started_at')"
  FINISHED="$(echo "$conv" | jq -r '.finished_at // empty')"
  TITLE="$(echo "$conv" | jq -r '.structured.title // "Untitled"')"
  OVERVIEW="$(echo "$conv" | jq -r '.structured.overview // ""')"
  EMOJI="$(echo "$conv" | jq -r '.structured.emoji // ""')"
  CATEGORY="$(echo "$conv" | jq -r '.structured.category // ""')"
  LANGUAGE="$(echo "$conv" | jq -r '.language // ""')"
  SOURCE="$(echo "$conv" | jq -r '.source // ""')"
  ADDRESS="$(echo "$conv" | jq -r '.geolocation.address // ""')"

  # Check state: is this conversation known?
  KNOWN_FINISHED="$(jq -r --arg id "$ID" '.conversations[$id].finished_at // empty' "$STATE_FILE")"
  KNOWN_PROCESSED="$(jq -r --arg id "$ID" '.conversations[$id].groq_processed // false' "$STATE_FILE")"

  # Skip if conversation is still in progress (no finished_at)
  if [[ -z "$FINISHED" ]]; then
    echo "  ⏳ $ID — still in progress, skipping"
    continue
  fi

  # Skip if already processed and finished_at hasn't changed
  if [[ "$KNOWN_PROCESSED" == "true" && "$KNOWN_FINISHED" == "$FINISHED" ]]; then
    continue
  fi

  IS_UPDATE=false
  if [[ -n "$KNOWN_FINISHED" && "$KNOWN_FINISHED" != "$FINISHED" ]]; then
    IS_UPDATE=true
    echo "  🔄 $ID — updated (finished_at changed)"
  fi

  # --- Save transcript file (ID-based naming) ---
  DATE_PREFIX="$(echo "$STARTED" | cut -c1-10)"
  TIME_PREFIX="$(echo "$STARTED" | cut -c12-16 | tr -d ':')"
  SAFE_TITLE="$(echo "$TITLE" | sed 's/[^a-zA-Z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' | cut -c1-60 | sed 's/.*/\L&/')"
  FILENAME="${DATE_PREFIX}-${TIME_PREFIX}-${SAFE_TITLE}.md"
  FILEPATH="$TRANSCRIPTS_DIR/$FILENAME"

  # Remove old file if title changed (ID-based tracking means we can find it)
  OLD_FILENAME="$(jq -r --arg id "$ID" '.conversations[$id].file // empty' "$STATE_FILE")"
  if [[ -n "$OLD_FILENAME" && "$OLD_FILENAME" != "$FILENAME" && -f "$TRANSCRIPTS_DIR/$OLD_FILENAME" ]]; then
    rm -f "$TRANSCRIPTS_DIR/$OLD_FILENAME"
    echo "  🗑️  Removed old file: $OLD_FILENAME"
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

  ACTION_ITEMS="$(echo "$conv" | jq -r '
    if .structured.action_items != null and (.structured.action_items | length) > 0 then
      .structured.action_items | map("- [ ] " + .description) | join("\n")
    else
      empty
    end
  ')"

  # Write markdown file (overwrite if updated)
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

  echo "  ✅ Saved: $FILENAME"

  # --- Groq classification + extraction ---
  CLASSIFICATION="skipped"
  EXTRACTED=""

  if [[ "$GROQ_AVAILABLE" == "true" ]]; then
    # Build speaker metadata
    SPEAKER_COUNT="$(echo "$conv" | jq '[.transcript_segments[]?.speaker_id] | unique | length')"
    SEGMENT_COUNT="$(echo "$conv" | jq '.transcript_segments | length')"
    SPEAKER_BREAKDOWN="$(echo "$conv" | jq -r '[.transcript_segments[]? | .speaker_name] | group_by(.) | map({speaker: .[0], segments: length}) | map("\(.speaker): \(.segments) segments") | join(", ")')"
    USER_SPOKE="$(echo "$conv" | jq '[.transcript_segments[]? | select(.speaker_name == "User")] | length')"
    USER_SEGMENTS="$(echo "$conv" | jq -r '[.transcript_segments[]? | select(.speaker_name == "User") | .text] | join(" ") | .[0:1000]')"

    # Fast-path: skip Groq for media/noise
    # 1) Simon never spoke → pure background audio
    # 2) Simon spoke very little (≤2 segments, ≤30 total words) relative to total → incidental noise while watching media
    USER_WORD_COUNT="$(echo "$USER_SEGMENTS" | wc -w)"
    USER_RATIO="$(echo "$conv" | jq --argjson u "$USER_SPOKE" --argjson t "$SEGMENT_COUNT" '
      if $t == 0 then 0 else ($u * 100 / $t) end
    ')"

    if [[ "$USER_SPOKE" -eq 0 ]]; then
      echo "  🔇 No 'User' segments — background media/noise, skipping Groq"
      TMP="$(mktemp)"
      jq --arg id "$ID" --arg file "$FILENAME" --arg fin "$FINISHED" \
        '.conversations[$id] = {file: $file, finished_at: $fin, groq_processed: true, classification: "media-auto"}' \
        "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
      continue
    fi

    if [[ "$USER_SPOKE" -le 2 && "$USER_WORD_COUNT" -le 30 && "$SEGMENT_COUNT" -gt 10 ]]; then
      echo "  🔇 User spoke $USER_SPOKE segments ($USER_WORD_COUNT words) out of $SEGMENT_COUNT total — likely background media, skipping Groq"
      TMP="$(mktemp)"
      jq --arg id "$ID" --arg file "$FILENAME" --arg fin "$FINISHED" \
        '.conversations[$id] = {file: $file, finished_at: $fin, groq_processed: true, classification: "media-auto-lowuser"}' \
        "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
      continue
    fi

    # Aggressive pre-filter: if Simon said < 15 words and recording has 20+ segments, it's media
    if [[ "$USER_WORD_COUNT" -lt 15 && "$SEGMENT_COUNT" -ge 20 ]]; then
      echo "  🔇 User said $USER_WORD_COUNT words across $SEGMENT_COUNT segments — background media, skipping Groq"
      TMP="$(mktemp)"
      jq --arg id "$ID" --arg file "$FILENAME" --arg fin "$FINISHED" \
        '.conversations[$id] = {file: $file, finished_at: $fin, groq_processed: true, classification: "media-auto-lowuser"}' \
        "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
      continue
    fi

    # Build the text to send to Groq (overview + metadata + Simon's words + full transcript context)
    GROQ_INPUT="Title: $TITLE
Category: $CATEGORY
Overview: $OVERVIEW
Speaker metadata: $SPEAKER_COUNT unique speaker(s), $SEGMENT_COUNT total segments [$SPEAKER_BREAKDOWN]
Simon spoke: $USER_SPOKE segments
Simon's words (User segments only): $USER_SEGMENTS
Full transcript (truncated, for context):
$(echo "$TRANSCRIPT" | head -c 3000)"

    GROQ_PROMPT='You analyze Omi wearable conversation transcripts for a user named Simon.
Simon wears this device throughout the day. It captures HIS conversations, but also picks up background audio (YouTube, podcasts, TV, music).

Classify this transcript and extract actionable information.

CLASSIFICATION (pick exactly one):
- "noise" — ambient sounds, gibberish, repetitive fragments, inaudible
- "media" — background media (YouTube, podcast, TV, music). Signs: tutorial language ("in this video", "lets take a look", "subscribe"), single continuous monologue with no conversational back-and-forth, educational/entertainment content not directed at anyone present
- "mundane" — casual conversation with no actionable content (small talk, routine chitchat, household noise, kids playing normally, routine requests like "pass the toilet paper")
- "actionable" — contains CONCRETE decisions, tasks, ideas, promises, reminders, or NOTABLE family moments (milestones, sweet/memorable events — NOT routine household chatter)
- "research" — Simon expressed curiosity, asked a question, or mentioned a topic worth researching. Signs: "I wonder if...", "what is the best...", "is there a...", "how does X work", comparing products/options, wanting to learn about something. Extract the research query and context. Can co-occur with actionable (use "actionable" if there are also concrete action items, but include research_queries in the output).

RULES:
- Simon is ALWAYS labeled "User" in transcripts. Other speakers are "Speaker N".
- ONLY extract action items from what SIMON (User) said. Ignore what other speakers said unless Simon explicitly agreed to it.
- Be conservative: only classify as "actionable" if there are CONCRETE items from Simon.
- Family moments count as actionable ONLY for milestones, genuinely sweet/memorable moments, or real decisions. Routine household chatter (bathroom, getting dressed, bedtime nagging, snack requests, potty talk) is MUNDANE, not actionable. Ask: "Would Simon want to remember this specific moment in a week?" If no → mundane.
- Work meetings where Simon commits to tasks or makes decisions are actionable.
- Simon saying "I should..." or "I need to..." = actionable (todo).
- Simon saying "We decided..." or agreeing to something = actionable (decision).
- Pure noise with no intelligible speech = noise.
- If Simon spoke very little and the rest is media/podcast/panel content = media (only extract from Simons words if they contain personal action items).
- Multi-speaker media (podcasts, panels, YouTube) where Simon interjects briefly: classify as media UNLESS Simons words contain clear personal action items — then classify as actionable but ONLY extract from Simons segments.
- CRITICAL: Short fragments from Simon like "as a leader", "yeah", "oh wow", "interesting" while media plays are NOT reflections or action items. These are involuntary reactions to video content. Classify as media.
- If 90%+ of the transcript is media content and Simon only has 1-3 short fragments, it is ALWAYS media regardless of what those fragments say.
- CONFIDENCE GATE: If you classify as "actionable" but your confidence is below 0.7, downgrade to "mundane" instead. When in doubt, choose mundane.
- If uncertain between mundane and actionable, choose mundane.

Respond in this EXACT JSON format (no markdown, no backticks):
{"classification":"noise|mundane|actionable|research","confidence":0.0-1.0,"items":[{"type":"todo|decision|idea|reminder|family|work|reflection","text":"concise one-liner","urgency":"high|medium|low"}],"research_queries":[{"query":"what to search for","context":"why Simon is curious about this"}]}'

    GROQ_PAYLOAD="$(jq -n \
      --arg model "$GROQ_MODEL" \
      --arg system "$GROQ_PROMPT" \
      --arg user "$GROQ_INPUT" \
      '{
        model: $model,
        messages: [
          {role: "system", content: $system},
          {role: "user", content: $user}
        ],
        temperature: 0.1,
        max_tokens: 512
      }')"

    GROQ_RESPONSE="$(curl -sf -X POST "$GROQ_API_BASE" \
      -H "Authorization: Bearer $GROQ_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$GROQ_PAYLOAD" 2>/dev/null)" || {
      echo "  ⚠️  Groq API failed for $ID, marking as unprocessed"
      # Update state as unprocessed so we retry next run
      TMP="$(mktemp)"
      jq --arg id "$ID" --arg file "$FILENAME" --arg fin "$FINISHED" \
        '.conversations[$id] = {file: $file, finished_at: $fin, groq_processed: false}' \
        "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
      continue
    }

    GROQ_CONTENT="$(echo "$GROQ_RESPONSE" | jq -r '.choices[0].message.content // empty')"

    if [[ -n "$GROQ_CONTENT" ]]; then
      # Parse Groq response
      CLASSIFICATION="$(echo "$GROQ_CONTENT" | jq -r '.classification // "unknown"' 2>/dev/null || echo "parse_error")"
      CONFIDENCE="$(echo "$GROQ_CONTENT" | jq -r '.confidence // 0' 2>/dev/null || echo "0")"

      echo "  🏷️  Classification: $CLASSIFICATION (confidence: $CONFIDENCE)"

      # Confidence gate: downgrade low-confidence actionable/research to mundane
      if [[ "$CLASSIFICATION" == "actionable" || "$CLASSIFICATION" == "research" ]]; then
        CONF_INT="$(echo "$CONFIDENCE" | awk '{printf "%d", $1 * 100}')"
        if [[ "$CONF_INT" -lt 70 ]]; then
          echo "  ⬇️  Downgrading $CLASSIFICATION → mundane (confidence $CONFIDENCE < 0.7)"
          CLASSIFICATION="mundane"
        fi
      fi

      # Queue research items
      if [[ "$CLASSIFICATION" == "research" || "$CLASSIFICATION" == "actionable" ]]; then
        RESEARCH_QUERIES="$(echo "$GROQ_CONTENT" | jq -c '.research_queries // [] | .[]' 2>/dev/null)"
        if [[ -n "$RESEARCH_QUERIES" ]]; then
          RESEARCH_QUEUE="$HOME/research/queue/pending.jsonl"
          mkdir -p "$(dirname "$RESEARCH_QUEUE")"
          echo "$RESEARCH_QUERIES" | while IFS= read -r rq; do
            RQ_SLUG="$(echo "$rq" | jq -r '.query' | sed 's/[^a-zA-Z0-9]/-/g; s/--*/-/g' | cut -c1-30 | tr '[:upper:]' '[:lower:]')"
            echo "$rq" | jq -c --arg id "${ID}-${RQ_SLUG}" --arg title "$TITLE" --arg omi_id "$ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              '{id: $id, source: "omi", query: .query, context: .context, omi_title: $title, omi_id: $omi_id, priority: "medium", created_at: $ts}' \
              >> "$RESEARCH_QUEUE"
            echo "  🔍 Queued research: $(echo "$rq" | jq -r '.query')"
          done
        fi
      fi

      if [[ "$CLASSIFICATION" == "actionable" ]]; then
        # Extract items and write to memory
        DATE_FOR_MEMORY="$DATE_PREFIX"
        MEMORY_FILE="$MEMORY_DIR/${DATE_FOR_MEMORY}.md"

        # Calculate staleness (hours since conversation finished)
        FINISHED_EPOCH="$(date -d "$FINISHED" +%s 2>/dev/null || echo "0")"
        NOW_EPOCH="$(date +%s)"
        STALE_HOURS=$(( (NOW_EPOCH - FINISHED_EPOCH) / 3600 ))

        # Build memory entry
        ITEMS_TEXT="$(echo "$GROQ_CONTENT" | jq -r '
          .items // [] | map("- **" + .type + ":** " + .text +
            (if .urgency == "high" then " 🔴" elif .urgency == "medium" then " 🟡" else "" end)
          ) | join("\n")' 2>/dev/null || echo "")"

        if [[ -n "$ITEMS_TEXT" ]]; then
          # Append to memory file
          NEED_HEADER=false
          if [[ ! -f "$MEMORY_FILE" ]]; then
            NEED_HEADER=true
          fi
          {
            if [[ "$NEED_HEADER" == "true" ]]; then
              echo "# $(date -d "$DATE_FOR_MEMORY" +"%B %d, %Y" 2>/dev/null || echo "$DATE_FOR_MEMORY")"
              echo ""
            fi
            echo "## Omi: $TITLE"
            echo ""
            echo "$ITEMS_TEXT"
            echo ""
          } >> "$MEMORY_FILE"

          echo "  📝 Written to memory: $MEMORY_FILE"

          # Write actionable items to notification queue (for main session pickup)
          NOTIFY_FILE="$OMI_DIR/.pending-notifications.jsonl"
          echo "$GROQ_CONTENT" | jq -c --arg title "$TITLE" --arg id "$ID" \
            --arg finished "$FINISHED" --argjson stale_hours "$STALE_HOURS" \
            '{conversation_id: $id, title: $title, finished_at: $finished,
              stale_hours: $stale_hours, classification, confidence, items}' \
            >> "$NOTIFY_FILE"
        fi
      fi
    fi
  fi

  # --- Update state ---
  TMP="$(mktemp)"
  jq --arg id "$ID" --arg file "$FILENAME" --arg fin "$FINISHED" \
    --arg cls "$CLASSIFICATION" \
    '.conversations[$id] = {file: $file, finished_at: $fin, groq_processed: true, classification: $cls}' \
    "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"

done

# --- Update last_api_sync to newest created_at ---
NEWEST="$(echo "$ALL_CONVERSATIONS" | jq -r '[.[].created_at] | sort | last // empty')"
if [[ -n "$NEWEST" ]]; then
  TMP="$(mktemp)"
  jq --arg ts "$NEWEST" '.last_api_sync = $ts' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
  echo "Updated last_api_sync: $NEWEST"
fi

echo "=== Pipeline complete ==="

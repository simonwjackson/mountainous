#!/usr/bin/env bash
# Dictation - speech-to-text for Wayland via Groq Whisper API
# Press once to start recording, press again to stop and type the transcription.

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOG_FILE="$RUNTIME_DIR/dictation.log"
TRANSCRIPT_FILE="$RUNTIME_DIR/dictation-transcript.txt"
PID_FILE="$RUNTIME_DIR/dictation-stt.pid"
RETURN_FLAG_FILE="$RUNTIME_DIR/dictation-send-return"
AUDIO_FILE="$RUNTIME_DIR/dictation-recording.wav"
BAR_STATE_CSS="$RUNTIME_DIR/ironbar-dictation.css"

GROQ_API_KEY="${GROQ_API_KEY:-}"
DICTATION_MODEL="${DICTATION_MODEL:-whisper-large-v3-turbo}"
DICTATION_LANGUAGE="${DICTATION_LANGUAGE:-en}"

# Load config if exists
if [[ -f "$CONFIG_DIR/dictation/config" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_DIR/dictation/config"
fi

# Parse flags
SEND_RETURN=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --return | -r)
      SEND_RETURN=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

log() {
  echo "[$(date '+%H:%M:%S')] $*" >>"$LOG_FILE"
}

bar_recording() {
  cat >"$BAR_STATE_CSS" <<'CSS'
#bar { background-color: rgba(191, 38, 38, 0.92); }
CSS
  ironbar style load-css "$BAR_STATE_CSS" >/dev/null 2>&1 || true
}

bar_processing() {
  cat >"$BAR_STATE_CSS" <<'CSS'
#bar { background-color: rgba(191, 130, 38, 0.92); }
CSS
  ironbar style load-css "$BAR_STATE_CSS" >/dev/null 2>&1 || true
}

bar_idle() {
  : >"$BAR_STATE_CSS"
  ironbar style load-css "$BAR_STATE_CSS" >/dev/null 2>&1 || true
}

transcribe() {
  local audio_file="$1"
  local output_file="$2"

  log "Transcribing via Groq (model: $DICTATION_MODEL)"
  log "Audio file size: $(stat -c%s "$audio_file" 2>/dev/null || echo "unknown") bytes"

  local response
  response=$(curl -s -w '\n%{http_code}' \
    "https://api.groq.com/openai/v1/audio/transcriptions" \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -F "file=@${audio_file}" \
    -F "model=${DICTATION_MODEL}" \
    -F "response_format=text" \
    -F "language=${DICTATION_LANGUAGE}" \
    2>>"$LOG_FILE")

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    log "ERROR: Groq API returned HTTP $http_code"
    log "Response: $body"
    rm -f "$audio_file"
    return 1
  fi

  echo "$body" >"$output_file"
  log "Transcript: $body"
  rm -f "$audio_file"
}

# Check if recording is currently running via PID file
if [[ -f "$PID_FILE" ]]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    log "=== Stopping recording (PID: $PID) ==="
    bar_processing

    sleep 1

    kill -INT "$PID"
    rm -f "$PID_FILE"

    while kill -0 "$PID" 2>/dev/null; do
      sleep 0.1
    done

    if [[ -f "$AUDIO_FILE" ]]; then
      transcribe "$AUDIO_FILE" "$TRANSCRIPT_FILE"
    else
      log "ERROR: Audio file not found at $AUDIO_FILE"
    fi

    bar_idle
    if [[ -s "$TRANSCRIPT_FILE" ]]; then
      TRANSCRIPT=$(cat "$TRANSCRIPT_FILE")
      sleep 0.2
      wtype -P super -P shift -P ctrl -P alt
      echo -n "$TRANSCRIPT" | wtype -
      if [[ -f "$RETURN_FLAG_FILE" ]]; then
        wtype -k Return
        rm -f "$RETURN_FLAG_FILE"
        log "Sent Return key"
      fi
      log "Done typing"
      rm -f "$TRANSCRIPT_FILE"
    else
      log "No transcript available"
      rm -f "$RETURN_FLAG_FILE"
    fi
    exit 0
  else
    log "Stale PID file, removing"
    rm -f "$PID_FILE"
    bar_idle
  fi
fi

# Validate API key
if [[ -z "$GROQ_API_KEY" ]]; then
  log "ERROR: GROQ_API_KEY not set"
  echo "ERROR: GROQ_API_KEY not set" >&2
  exit 1
fi

# Start recording
log "=== Starting recording ==="
bar_recording
rm -f "$TRANSCRIPT_FILE"
rm -f "$AUDIO_FILE"

if [[ "$SEND_RETURN" == "true" ]]; then
  touch "$RETURN_FLAG_FILE"
  log "Will send Return key after transcription"
else
  rm -f "$RETURN_FLAG_FILE"
fi

log "Recording to $AUDIO_FILE"
rec -q -r 16000 -c 1 "$AUDIO_FILE" 2>>"$LOG_FILE" &
REC_PID=$!
echo "$REC_PID" >"$PID_FILE"
log "Started rec with PID: $REC_PID"

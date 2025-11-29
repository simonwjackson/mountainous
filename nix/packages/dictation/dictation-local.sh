#!/usr/bin/env bash
# Local dictation - uses whisper-cli directly on this machine

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOG_FILE="$RUNTIME_DIR/dictation.log"
TRANSCRIPT_FILE="$RUNTIME_DIR/dictation-transcript.txt"
PID_FILE="$RUNTIME_DIR/dictation-stt.pid"
AMBIENT_PID_FILE="$RUNTIME_DIR/dictation-ambient.pid"
WAITING_PID_FILE="$RUNTIME_DIR/dictation-waiting.pid"
RETURN_FLAG_FILE="$RUNTIME_DIR/dictation-send-return"
AUDIO_FILE="$RUNTIME_DIR/dictation-recording.wav"

# Load config if exists
if [[ -f "$CONFIG_DIR/dictation/config" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_DIR/dictation/config"
fi

WHISPER_MODEL="${DICTATION_WHISPER_MODEL:-}"

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
  echo "[$(date '+%H:%M:%S')] [local] $*" >>"$LOG_FILE"
}

play_start() {
  play -n synth 0.8 sine 550:580 sine 825:870 fade l 0.18 0.8 0.55 vol 0.08 &
}

start_waiting() {
  play -n synth 0.8 sine 550:580 sine 825:870 fade l 0.18 0.8 0.55 vol 0.08 repeat - &
  echo $! >"$WAITING_PID_FILE"
}

stop_waiting() {
  if [[ -f "$WAITING_PID_FILE" ]]; then
    kill $(cat "$WAITING_PID_FILE") 2>/dev/null
    rm -f "$WAITING_PID_FILE"
  fi
}

start_ambient() {
  play -n -c1 synth whitenoise lowpass -1 120 lowpass -1 120 lowpass -1 120 gain +16 vol 0.5 fade t 2 &
  echo $! >"$AMBIENT_PID_FILE"
}

stop_ambient() {
  if [[ -f "$AMBIENT_PID_FILE" ]]; then
    AMBIENT_PID=$(cat "$AMBIENT_PID_FILE")
    rm -f "$AMBIENT_PID_FILE"
    play -n -c1 synth 0.5 whitenoise lowpass -1 120 lowpass -1 120 lowpass -1 120 gain +16 vol 0.5 fade t 0 0.5 0.5 &
    kill $AMBIENT_PID 2>/dev/null
  fi
}

transcribe() {
  local audio_file="$1"
  local output_file="$2"

  log "Transcribing with whisper-cli (model: $WHISPER_MODEL)"

  if [[ -z "$WHISPER_MODEL" ]] || [[ ! -f "$WHISPER_MODEL" ]]; then
    log "ERROR: Whisper model not found at $WHISPER_MODEL"
    return 1
  fi

  whisper-cli -m "$WHISPER_MODEL" -f "$audio_file" -nt 2>>"$LOG_FILE" >"$output_file"
  local exit_code=$?
  log "whisper-cli exit code: $exit_code"
  rm -f "$audio_file"
}

# Check if recording is currently running via PID file
if [[ -f "$PID_FILE" ]]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    log "=== Stopping recording (PID: $PID) ==="
    stop_ambient
    start_waiting
    kill -INT "$PID"
    rm -f "$PID_FILE"

    # Buffer drain delay - wait for audio buffers to fully flush
    sleep 1

    if [[ -f "$AUDIO_FILE" ]]; then
      transcribe "$AUDIO_FILE" "$TRANSCRIPT_FILE"
    else
      log "ERROR: Audio file not found at $AUDIO_FILE"
    fi

    stop_waiting
    if [[ -s "$TRANSCRIPT_FILE" ]]; then
      TRANSCRIPT=$(cat "$TRANSCRIPT_FILE")
      log "Transcript: $TRANSCRIPT"
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
  fi
fi

# Start recording
log "=== Starting recording ==="
play_start
start_ambient
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

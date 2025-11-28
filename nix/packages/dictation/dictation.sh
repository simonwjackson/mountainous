#!/usr/bin/env bash

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOG_FILE="$RUNTIME_DIR/dictation.log"
TRANSCRIPT_FILE="$RUNTIME_DIR/dictation-transcript.txt"
PID_FILE="$RUNTIME_DIR/dictation-stt.pid"
AMBIENT_PID_FILE="$RUNTIME_DIR/dictation-ambient.pid"
WAITING_PID_FILE="$RUNTIME_DIR/dictation-waiting.pid"

log() {
  echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

play_start() {
  play -n synth 0.8 sine 550:580 sine 825:870 fade l 0.18 0.8 0.55 vol 0.08 &
}

start_waiting() {
  play -n synth 0.8 sine 550:580 sine 825:870 fade l 0.18 0.8 0.55 vol 0.08 repeat - &
  echo $! > "$WAITING_PID_FILE"
}

stop_waiting() {
  if [[ -f "$WAITING_PID_FILE" ]]; then
    kill $(cat "$WAITING_PID_FILE") 2>/dev/null
    rm -f "$WAITING_PID_FILE"
  fi
}

start_ambient() {
  play -n -c1 synth whitenoise lowpass -1 120 lowpass -1 120 lowpass -1 120 gain +16 vol 0.5 fade t 2 &
  echo $! > "$AMBIENT_PID_FILE"
}

stop_ambient() {
  if [[ -f "$AMBIENT_PID_FILE" ]]; then
    AMBIENT_PID=$(cat "$AMBIENT_PID_FILE")
    rm -f "$AMBIENT_PID_FILE"
    play -n -c1 synth 0.5 whitenoise lowpass -1 120 lowpass -1 120 lowpass -1 120 gain +16 vol 0.5 fade t 0 0.5 0.5 &
    kill $AMBIENT_PID 2>/dev/null
  fi
}

ACTION="${1:-toggle}"

case "$ACTION" in
  toggle|*)
    # Check if stt is currently running via PID file
    if [[ -f "$PID_FILE" ]]; then
      PID=$(cat "$PID_FILE")
      if kill -0 "$PID" 2>/dev/null; then
        log "=== Stopping recording (PID: $PID) ==="
        stop_ambient
        start_waiting
        kill -INT "$PID"
        rm -f "$PID_FILE"

        log "Waiting for transcription..."
        for i in {1..10}; do
          sleep 0.5
          if [[ -s "$TRANSCRIPT_FILE" ]]; then
            log "Transcript ready after ${i}*0.5 seconds"
            break
          fi
        done

        stop_waiting
        if [[ -s "$TRANSCRIPT_FILE" ]]; then
          TRANSCRIPT=$(cat "$TRANSCRIPT_FILE")
          log "Transcript: $TRANSCRIPT"
          sleep 0.2
          wtype -P super -P shift -P ctrl -P alt
          echo -n "$TRANSCRIPT" | wtype -
          log "Done typing"
          rm -f "$TRANSCRIPT_FILE"
        else
          log "No transcript available"
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
    stt > "$TRANSCRIPT_FILE" 2>> "$LOG_FILE" &
    STT_PID=$!
    echo "$STT_PID" > "$PID_FILE"
    log "Started stt with PID: $STT_PID"
    ;;
esac

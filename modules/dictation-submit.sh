audio_file="${1:-}"
send_enter="${2:-0}"
session_id="${3:-${XDG_SESSION_ID:-}}"

if [ -z "$audio_file" ] || [ ! -s "$audio_file" ]; then
  echo "dictation-submit: audio file is missing or empty" >&2
  exit 20
fi

backend_order="${DICTATION_BACKEND_ORDER:-zao,groq}"
zao_url="${DICTATION_ZAO_URL:-https://dictate.hummingbird-lake.ts.net/v1/audio/transcriptions}"
groq_url="${DICTATION_GROQ_URL:-https://api.groq.com/openai/v1/audio/transcriptions}"
groq_key_file="${DICTATION_GROQ_KEY_FILE:-}"
zao_fallback_ms="${DICTATION_ZAO_FALLBACK_MS:-3000}"
case "$zao_fallback_ms" in
  ''|*[!0-9]*) zao_fallback_ms=3000 ;;
esac

session_is_locked() {
  if [ -z "$session_id" ]; then
    return 0
  fi

  if ! locked=$(loginctl show-session "$session_id" \
    --property=LockedHint --value 2>/dev/null); then
    return 0
  fi
  [ "$locked" != "no" ]
}

require_unlocked() {
  if session_is_locked; then
    echo "dictation-submit: session is locked" >&2
    exit 21
  fi
}

transcript=""
selected_backend=""

transcribe() {
  local backend="$1"
  local url="$2"
  local output=""
  local http_code=""
  local body=""

  # This is the only progress protocol Quickshell reads. It contains
  # a backend name, never transcript text or a response body.
  printf 'backend %s\n' "$backend"

  local curl_args=(
    --silent
    --show-error
    --location
    --write-out $'\n%{http_code}'
    -F "file=@$audio_file;type=audio/wav"
    -F "model=whisper-large-v3-turbo"
    -F "language=en"
    -F "response_format=json"
  )

  if [ "$backend" = "zao" ]; then
    if ! output=$(curl --connect-timeout 3 --max-time 3 \
      "${curl_args[@]}" "$url" 2>/dev/null); then
      return 1
    fi
  elif [ "$backend" = "groq" ]; then
    if [ -z "$groq_key_file" ] || [ ! -r "$groq_key_file" ]; then
      return 1
    fi

    # Pass the bearer token through a private file descriptor. The token never
    # enters the Nix store, process arguments, or logs.
    local token=""
    local curl_status=0
    token=$(tr -d '\r\n' < "$groq_key_file")
    if [ -z "$token" ]; then
      return 1
    fi
    output=$(curl --connect-timeout 10 --max-time 30 \
      --config <(printf 'header = "Authorization: Bearer %s"\n' "$token") \
      "${curl_args[@]}" "$url" 2>/dev/null) || curl_status=$?
    unset token
    if [ "$curl_status" -ne 0 ]; then
      return 1
    fi
  else
    return 1
  fi

  http_code="${output##*$'\n'}"
  body="${output%$'\n'*}"
  if [ "$http_code" != "200" ]; then
    return 1
  fi

  # Trim only the two ends. jq keeps all internal white space and punctuation
  # unchanged.
  if ! transcript=$(printf '%s' "$body" \
    | jq -jr '(.text // "") | gsub("^\\s+|\\s+$"; "")' 2>/dev/null); then
    transcript=""
    return 1
  fi
  if [ -z "$transcript" ]; then
    return 1
  fi

  selected_backend="$backend"
  return 0
}

require_unlocked

transcribed=0
IFS=',' read -r -a backends <<< "$backend_order"
for backend in "${backends[@]}"; do
  # A lock during Zao's timeout must stop the Groq fallback as well as later
  # insertion. Quickshell keeps this take queued until unlock.
  require_unlocked
  case "$backend" in
    zao)
      started_ms=$(date +%s%3N)
      if transcribe zao "$zao_url"; then
        transcribed=1
        break
      fi
      elapsed_ms=$(( $(date +%s%3N) - started_ms ))
      if [ "$elapsed_ms" -lt "$zao_fallback_ms" ]; then
        remaining_ms=$(( zao_fallback_ms - elapsed_ms ))
        sleep "$(printf '%d.%03d' \
          "$(( remaining_ms / 1000 ))" "$(( remaining_ms % 1000 ))")"
      fi
      ;;
    groq)
      if transcribe groq "$groq_url"; then
        transcribed=1
        break
      fi
      ;;
  esac
done

if [ "$transcribed" -ne 1 ]; then
  echo "dictation-submit: all configured backends failed" >&2
  exit 20
fi

# The lock can arrive while a backend works. Fail closed before either
# clipboard or keyboard action. Quickshell keeps the audio and retries it after
# the session unlocks.
require_unlocked

# Keep both Wayland selections. The transcript travels through pipes and shell
# memory only. It is never a command argument.
if ! printf '%s' "$transcript" | wl-copy --primary --trim-newline; then
  unset transcript
  echo "dictation-submit: insertion failed" >&2
  exit 20
fi
if ! printf '%s' "$transcript" | wl-copy --trim-newline; then
  unset transcript
  echo "dictation-submit: insertion failed" >&2
  exit 20
fi
require_unlocked
if ! wtype -M shift -k Insert -m shift; then
  unset transcript
  echo "dictation-submit: insertion failed" >&2
  exit 20
fi
if [ "$send_enter" = "1" ]; then
  # The text is already inserted. If the lock arrived now, report success and
  # omit Return. Requeueing would paste the same transcript a second time.
  if session_is_locked; then
    unset transcript
    printf 'done %s\n' "$selected_backend"
    exit 0
  fi
  if ! wtype -k Return; then
    unset transcript
    echo "dictation-submit: insertion failed" >&2
    exit 20
  fi
fi
unset transcript

printf 'done %s\n' "$selected_backend"

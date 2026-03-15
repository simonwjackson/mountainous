# Oura Ring → local JSONL sync
# Pulls daily data from Oura API v2 and appends to per-type JSONL files
# Idempotent: tracks per-endpoint latest day, deduplicates on append


DATA_DIR="$HOME/biometrics/data"
STATE_FILE="$HOME/biometrics/.sync-state.json"
TOKEN_FILE="/run/agenix/oura-api-token"
LOCK_FILE="$HOME/biometrics/.sync.lock"

ENDPOINTS=(
  daily_sleep
  daily_activity
  daily_readiness
  daily_spo2
  daily_stress
  daily_resilience
  daily_cardiovascular_age
  sleep
  sleep_time
  workout
  tag
  session
  rest_mode_period
  ring_configuration
  enhanced_tag
  heartrate
)

# --- Lock ---
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another sync is running, exiting."
  exit 0
fi

mkdir -p "$DATA_DIR"

TOKEN=$(cat "$TOKEN_FILE")

TODAY=$(date +%Y-%m-%d)

# --- Load per-endpoint state ---
# State format: {"endpoints": {"daily_sleep": "2026-02-22", ...}, "last_run": "2026-02-23"}
if [[ -f "$STATE_FILE" ]]; then
  STATE=$(cat "$STATE_FILE")
else
  STATE='{}'
fi

echo "Sync run: $TODAY"

TOTAL=0
NEW_ENDPOINTS_STATE=$(echo "$STATE" | jq '.endpoints // {}')

for endpoint in "${ENDPOINTS[@]}"; do
  outfile="$DATA_DIR/${endpoint}.jsonl"

  # Get last synced day for this endpoint from state
  LAST_DAY=$(echo "$NEW_ENDPOINTS_STATE" | jq -r --arg ep "$endpoint" '.[$ep] // empty')

  if [[ -z "$LAST_DAY" ]]; then
    # No state — check the file for the latest day, or backfill 365 days
    if [[ -f "$outfile" ]]; then
      # Try .day first, then extract date from .timestamp for heartrate-style endpoints
      LAST_DAY=$(tail -1 "$outfile" | jq -r '.day // (.timestamp // empty | split("T")[0])' 2>/dev/null || true)
    fi
    if [[ -z "$LAST_DAY" ]]; then
      LAST_DAY=$(date -d "30 days ago" +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)
    fi
  fi

  # Start from the last synced day (inclusive — we deduplicate below)
  START_DATE="$LAST_DAY"

  # heartrate/enhanced_tag endpoints use datetime params, others use date
  if [[ "$endpoint" == "heartrate" || "$endpoint" == "enhanced_tag" ]]; then
    api_url="https://api.ouraring.com/v2/usercollection/${endpoint}?start_datetime=${START_DATE}T00:00:00&end_datetime=${TODAY}T23:59:59"
  else
    api_url="https://api.ouraring.com/v2/usercollection/${endpoint}?start_date=${START_DATE}&end_date=${TODAY}"
  fi

  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    "$api_url")

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    echo "WARN: $endpoint returned $http_code, skipping"
    continue
  fi

  # Collect all data (including paginated) into a temp file to avoid SIGPIPE on large responses
  tmp_all=$(mktemp)
  echo "$body" | jq -c '.data[]' >> "$tmp_all" 2>/dev/null || true

  next_token=$(echo "$body" | jq -r '.next_token // empty')
  while [[ -n "${next_token:-}" ]]; do
    response=$(curl -s -w "\n%{http_code}" \
      -H "Authorization: Bearer $TOKEN" \
      "https://api.ouraring.com/v2/usercollection/${endpoint}?next_token=${next_token}")

    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
      echo "WARN: $endpoint pagination returned $http_code, stopping"
      break
    fi

    echo "$body" | jq -c '.data[]' >> "$tmp_all" 2>/dev/null || true

    next_token=$(echo "$body" | jq -r '.next_token // empty')
  done

  if [[ ! -s "$tmp_all" ]]; then
    echo "$endpoint: no new data"
    rm -f "$tmp_all"
    continue
  fi

  all_data=$(cat "$tmp_all")

  # Deduplicate: build set of existing IDs (prefer 'id', fall back to 'day')
  # For endpoints with unique 'id' field, use that; otherwise use 'day'
  tmp_new=$(mktemp)
  if [[ -f "$outfile" ]]; then
    # Check if records have 'id' field
    has_id=$(echo "$all_data" | head -1 | jq -r '.id // empty')
    if [[ -n "$has_id" ]]; then
      # Deduplicate by id
      existing_ids=$(jq -r '.id // empty' "$outfile" | sort -u)
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        rid=$(echo "$line" | jq -r '.id // empty')
        if ! grep -qxF "$rid" <<< "$existing_ids"; then
          echo "$line" >> "$tmp_new"
        fi
      done <<< "$all_data"
    else
      # Deduplicate by day
      existing_days=$(jq -r '.day // empty' "$outfile" | sort -u)
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        rday=$(echo "$line" | jq -r '.day // empty')
        if ! grep -qxF "$rday" <<< "$existing_days"; then
          echo "$line" >> "$tmp_new"
        fi
      done <<< "$all_data"
    fi
  else
    # No existing file — all data is new
    echo "$all_data" > "$tmp_new"
  fi

  count=$(wc -l < "$tmp_new" | tr -d ' ')
  if [[ "$count" -gt 0 ]]; then
    cat "$tmp_new" >> "$outfile"
    echo "$endpoint: +${count} records"
    TOTAL=$((TOTAL + count))
  else
    echo "$endpoint: no new data"
  fi

  rm -f "$tmp_new" "$tmp_all"

  # Track the latest day from API response for this endpoint
  latest_day=$(echo "$all_data" | jq -r '.day // (.timestamp // empty | split("T")[0])' | grep -v '^$' | sort | tail -1)
  if [[ -n "$latest_day" ]]; then
    NEW_ENDPOINTS_STATE=$(echo "$NEW_ENDPOINTS_STATE" | jq --arg ep "$endpoint" --arg d "$latest_day" '.[$ep] = $d')
  fi
done

# Update state with per-endpoint tracking
jq -n --arg run "$TODAY" --argjson eps "$NEW_ENDPOINTS_STATE" \
  '{"last_run": $run, "endpoints": $eps}' > "$STATE_FILE"

echo "Done. Total: ${TOTAL} new records."

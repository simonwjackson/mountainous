
# Oura Ring → local JSONL sync
# Pulls daily data from Oura API v2 and appends to per-type JSONL files
# Idempotent: uses state file to track last sync date, won't duplicate


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
  heartrate
  workout
  tag
  enhanced_tag
  session
  rest_mode_period
  ring_configuration
)

# --- Lock ---
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another sync is running, exiting."
  exit 0
fi

mkdir -p "$DATA_DIR"

TOKEN=$(cat "$TOKEN_FILE")

# --- State ---
if [[ -f "$STATE_FILE" ]]; then
  LAST_SYNC=$(jq -r '.last_sync_date // empty' "$STATE_FILE" 2>/dev/null || true)
fi

if [[ -z "${LAST_SYNC:-}" ]]; then
  # First run: backfill 90 days
  LAST_SYNC=$(date -d "365 days ago" +%Y-%m-%d 2>/dev/null || date -v-90d +%Y-%m-%d)
fi

TODAY=$(date +%Y-%m-%d)

if [[ "$LAST_SYNC" == "$TODAY" ]]; then
  echo "Already synced today ($TODAY), skipping."
  exit 0
fi

# Start from day after last sync
START_DATE=$(date -d "$LAST_SYNC + 1 day" +%Y-%m-%d 2>/dev/null || date -v+1d -j -f %Y-%m-%d "$LAST_SYNC" +%Y-%m-%d)

echo "Syncing from $START_DATE to $TODAY"

TOTAL=0
for endpoint in "${ENDPOINTS[@]}"; do
  outfile="$DATA_DIR/${endpoint}.jsonl"

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

  # Each response has { "data": [...] } — extract items and append as individual JSONL records
  count=$(echo "$body" | jq '.data | length')
  if [[ "$count" -gt 0 ]]; then
    echo "$body" | jq -c '.data[]' >> "$outfile"
    echo "$endpoint: +${count} records"
    TOTAL=$((TOTAL + count))
  else
    echo "$endpoint: no new data"
  fi

  # Handle pagination (next_token)
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

    page_count=$(echo "$body" | jq '.data | length')
    if [[ "$page_count" -gt 0 ]]; then
      echo "$body" | jq -c '.data[]' >> "$outfile"
      echo "$endpoint: +${page_count} records (page)"
      TOTAL=$((TOTAL + page_count))
    fi

    next_token=$(echo "$body" | jq -r '.next_token // empty')
  done
done

# Update state
jq -n --arg date "$TODAY" '{"last_sync_date": $date}' > "$STATE_FILE"

echo "Done. Total: ${TOTAL} new records."

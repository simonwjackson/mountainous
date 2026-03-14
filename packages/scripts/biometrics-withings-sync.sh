
# Withings → local JSONL sync
# Pulls weight/body comp measurements, auto-refreshes tokens


DATA_DIR="$HOME/biometrics/data"
STATE_FILE="$HOME/biometrics/.withings-sync-state.json"
TOKEN_FILE="$HOME/.config/withings/tokens.json"
CLIENT_ID=$(cat "/run/agenix/withings-client-id")
CLIENT_SECRET=$(cat "/run/agenix/withings-client-secret")
LOCK_FILE="$HOME/biometrics/.withings-sync.lock"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another sync running, exiting."
  exit 0
fi

mkdir -p "$DATA_DIR"

# --- Token refresh ---
refresh_token() {
  local refresh_tok=$(jq -r '.refresh_token' "$TOKEN_FILE")
  local resp=$(curl -s -X POST "https://wbsapi.withings.net/v2/oauth2" \
    -d "action=requesttoken" \
    -d "grant_type=refresh_token" \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    -d "refresh_token=$refresh_tok")
  
  local status=$(echo "$resp" | jq -r '.status')
  if [[ "$status" != "0" ]]; then
    echo "ERROR: Token refresh failed: $resp"
    exit 1
  fi
  
  echo "$resp" | jq '.body' > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  echo "Tokens refreshed."
}

get_token() {
  jq -r '.access_token' "$TOKEN_FILE"
}

# --- Fetch measurements ---
fetch_measures() {
  local token=$(get_token)
  local startdate=$1
  local enddate=$2
  
  local resp=$(curl -s -X POST "https://wbsapi.withings.net/measure" \
    -d "action=getmeas" \
    -d "access_token=$token" \
    -d "meastypes=1,5,6,8,76,77,88" \
    -d "category=1" \
    -d "startdate=$startdate" \
    -d "enddate=$enddate")
  
  local status=$(echo "$resp" | jq -r '.status')
  
  # 401 = expired token, refresh and retry
  if [[ "$status" == "401" ]]; then
    refresh_token
    token=$(get_token)
    resp=$(curl -s -X POST "https://wbsapi.withings.net/measure" \
      -d "action=getmeas" \
      -d "access_token=$token" \
      -d "meastypes=1,5,6,8,76,77,88" \
      -d "category=1" \
      -d "startdate=$startdate" \
      -d "enddate=$enddate")
    status=$(echo "$resp" | jq -r '.status')
  fi
  
  if [[ "$status" != "0" ]]; then
    echo "ERROR: API returned status $status"
    echo "$resp" | jq .
    exit 1
  fi
  
  echo "$resp"
}

# --- State ---
LAST_SYNC=0
if [[ -f "$STATE_FILE" ]]; then
  LAST_SYNC=$(jq -r '.last_sync_epoch // 0' "$STATE_FILE" 2>/dev/null || echo 0)
fi

NOW=$(date +%s)
OUTFILE="$DATA_DIR/withings_body.jsonl"

echo "Syncing Withings from epoch $LAST_SYNC to $NOW"

resp=$(fetch_measures "$LAST_SYNC" "$NOW")

# Convert measurement groups to JSONL
echo "$resp" | python3 -c "
import json, sys, datetime

TYPE_NAMES = {1:'weight_kg', 5:'fat_free_mass_kg', 6:'fat_ratio_pct', 8:'fat_mass_kg', 76:'muscle_mass_kg', 77:'hydration_kg', 88:'bone_mass_kg'}

data = json.load(sys.stdin)
groups = data['body']['measuregrps']
for g in groups:
    record = {
        'source': 'withings',
        'grpid': g['grpid'],
        'timestamp': g['date'],
        'category': g.get('category'),
    }
    for m in g['measures']:
        name = TYPE_NAMES.get(m['type'], f'type_{m[\"type\"]}')
        val = m['value'] * (10 ** m['unit'])
        record[name] = round(val, 3)
    dt = datetime.datetime.utcfromtimestamp(g['date'])
    record['day'] = dt.strftime('%Y-%m-%d')
    record['time'] = dt.strftime('%H:%M:%S')
    print(json.dumps(record))
print(f'{len(groups)} new records', file=sys.stderr)
" >> "$OUTFILE"

# Deduplicate by grpid
if [[ -f "$OUTFILE" ]]; then
  python3 -c "
import json
seen = set()
records = []
with open('$OUTFILE') as f:
    for line in f:
        r = json.loads(line)
        gid = r.get('grpid')
        if gid not in seen:
            seen.add(gid)
            records.append(line)
with open('$OUTFILE', 'w') as f:
    f.writelines(records)
print(f'{len(records)} unique records')
"
fi

jq -n --arg epoch "$NOW" '{"last_sync_epoch": ($epoch | tonumber)}' > "$STATE_FILE"

echo "Done."

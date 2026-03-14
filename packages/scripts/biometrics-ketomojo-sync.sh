
# Keto-Mojo → local JSONL sync
# Pulls glucose/ketone readings from MyMojoHealth API


DATA_DIR="$HOME/biometrics/data"
TOKEN_FILE="$HOME/.config/ketomojo/tokens.json"
OUTFILE="$DATA_DIR/ketomojo_readings.jsonl"
LOCK_FILE="$HOME/biometrics/.ketomojo-sync.lock"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another sync running, exiting."
  exit 0
fi

mkdir -p "$DATA_DIR"

TOKEN=$(jq -r '.access_token' "$TOKEN_FILE")

# Test token validity
status=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" \
  "https://api.us.mymojohealth.com/api/v1/readings?page_size=1")

if [[ "$status" == "401" || "$status" == "403" ]]; then
  echo "ERROR: Token expired. Re-auth needed."
  echo "TOKEN_EXPIRED"
  exit 1
fi

# Fetch all readings
resp=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.us.mymojohealth.com/api/v1/readings?scroll=true&page_size=10000")

# Convert to JSONL with dedup
echo "$resp" | python3 -c "
import json, sys

raw = sys.stdin.read()
try:
    parsed = json.loads(raw)
    data = parsed if isinstance(parsed, list) else []
except json.JSONDecodeError:
    print('ERROR: Failed to parse API response', file=sys.stderr)
    sys.exit(1)

outfile = '$OUTFILE'

# Load existing IDs
existing_ids = set()
try:
    with open(outfile) as f:
        for line in f:
            r = json.loads(line)
            existing_ids.add(r.get('reading_id'))
except FileNotFoundError:
    pass

new_count = 0
with open(outfile, 'a') as f:
    for r in data:
        if r.get('reading_id') not in existing_ids:
            r['source_app'] = 'ketomojo'
            r['day'] = r['reading_timestamp'][:10]
            f.write(json.dumps(r) + '\n')
            existing_ids.add(r['reading_id'])
            new_count += 1

print(f'{new_count} new readings (total API: {len(data)})')
"

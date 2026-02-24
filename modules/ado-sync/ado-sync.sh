# ado-sync.sh — Pull ADO work items via pure REST API (no az CLI needed)
# Wrapped by writeShellApplication — bash + set -euo pipefail are implicit.

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/flakey/ado"
mkdir -p "$CACHE_DIR"

TENANT_ID="fa5bd160-5076-426d-8a80-2ff7881e8a0a"
CLIENT_ID="04b07795-8ddb-461a-bbee-02f9e1bf7b46"  # Azure CLI public client
DEVOPS_RESOURCE="499b84ac-1321-427f-aa17-267ca6975798"
ORG="https://dev.azure.com/amazeinsights"

TOKEN_FILE="${CACHE_DIR}/refresh-token"
SEED_TOKEN="/run/agenix/ado-refresh-token"

# Bootstrap: if no mutable token, copy from agenix seed
if [ ! -f "$TOKEN_FILE" ] && [ -f "$SEED_TOKEN" ]; then
  cp "$SEED_TOKEN" "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
fi

if [ ! -f "$TOKEN_FILE" ]; then
  echo "ERROR: No refresh token available at $TOKEN_FILE or $SEED_TOKEN" >&2
  exit 1
fi

REFRESH_TOKEN=$(cat "$TOKEN_FILE")

# Exchange refresh token for access token (also returns new refresh token)
TOKEN_RESPONSE=$(curl -s -X POST \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
  -d "client_id=${CLIENT_ID}" \
  -d "grant_type=refresh_token" \
  -d "refresh_token=${REFRESH_TOKEN}" \
  -d "scope=${DEVOPS_RESOURCE}/.default")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')
NEW_REFRESH=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token // empty')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: Token exchange failed: $(echo "$TOKEN_RESPONSE" | jq -r '.error_description // .error // "unknown"')" >&2
  exit 1
fi

# Save rotated refresh token
if [ -n "$NEW_REFRESH" ]; then
  echo -n "$NEW_REFRESH" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
fi

# --- WIQL + batch fetch ---

wiql_query() {
  local wiql="$1"
  curl -s -X POST "${ORG}/_apis/wit/wiql?api-version=7.1" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"${wiql}\"}" \
    | jq -r '[.workItems[].id] | join(",")'
}

batch_fetch() {
  local ids="$1"
  local outfile="$2"

  if [ -z "$ids" ]; then
    echo "[]" > "$outfile"
    return
  fi

  curl -s "${ORG}/_apis/wit/workitems?ids=${ids}&\$expand=relations&api-version=7.1" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    | jq '.value // []' > "$outfile"
}

# Stories (Active, assigned to me)
STORY_IDS=$(wiql_query "SELECT [System.Id] FROM WorkItems WHERE [System.AssignedTo] = @Me AND [System.State] = 'Active' AND [System.WorkItemType] = 'User Story'")

# Tasks (Active + New, assigned to me)
TASK_IDS=$(wiql_query "SELECT [System.Id] FROM WorkItems WHERE [System.AssignedTo] = @Me AND ([System.State] = 'Active' OR [System.State] = 'New') AND [System.WorkItemType] = 'Task'")

batch_fetch "$STORY_IDS" "${CACHE_DIR}/stories.json.tmp"
batch_fetch "$TASK_IDS" "${CACHE_DIR}/tasks.json.tmp"

# Atomic swap
mv "${CACHE_DIR}/stories.json.tmp" "${CACHE_DIR}/stories.json"
mv "${CACHE_DIR}/tasks.json.tmp" "${CACHE_DIR}/tasks.json"
date -Iseconds > "${CACHE_DIR}/last-sync"

echo "ADO sync: $(jq length "${CACHE_DIR}/stories.json") stories, $(jq length "${CACHE_DIR}/tasks.json") tasks"

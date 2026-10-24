#!/usr/bin/env bash
# Read-only MCP adapter. Stdout is systems JSON, unavailable, or error.
set -euo pipefail
# A caller's shell tracing must never expose credentials.
set +x

token_file=${BESZEL_MCP_TOKEN_FILE:-}
if [[ -z "$token_file" || ! -f "$token_file" || ! -r "$token_file" || ! -s "$token_file" ]]; then
  printf 'unavailable\n'
  exit 0
fi

# Only the descriptor path appears in argv. The header is streamed, never
# stored on disk or expanded as a command argument. Suppress transport errors
# so stderr cannot become a second, unstructured output contract.
if ! response=$(curl --disable --silent --max-time 10 \
  --request POST 'https://beszel-mcp.hummingbird-lake.ts.net/mcp' \
  --header @/dev/fd/3 \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"list_systems","arguments":{}}}' \
  --write-out $'\n%{http_code}' \
  3< <(printf 'Authorization: Bearer '; tr -d '\r\n' < "$token_file"; printf '\n') 2>/dev/null); then
  printf 'unavailable\n'
  exit 0
fi

http_code=${response##*$'\n'}
if [[ ! "$http_code" =~ ^2[0-9][0-9]$ ]]; then
  printf 'error\n'
  exit 0
fi
body=${response%$'\n'*}
# MCP may return JSON or an SSE data frame. Decode the nested JSON string and
# validate the display-data boundary. Never execute any field from the hub.
if ! systems=$(printf '%s' "$body" | jq -Rsc '
  (try fromjson catch (
    split("\n") | map(select(startswith("data:")) | ltrimstr("data:") | ltrimstr(" ")) | join("\n") | fromjson
  ))
  | if .error != null or .result.isError == true then error("MCP error") else .result.content[0].text | fromjson end
  | .systems
  | if type == "array" and all(.[]; type == "object" and (.name | type == "string") and (.status | IN("up", "down", "paused", "pending")))
    then . else error("Invalid systems") end
' 2>/dev/null); then
  printf 'error\n'
  exit 0
fi
printf '%s\n' "$systems"

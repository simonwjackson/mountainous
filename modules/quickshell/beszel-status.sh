#!/usr/bin/env bash
# Read-only MCP adapter. Two forms:
#
#   beszel-status              systems JSON, unavailable, or error
#   beszel-status host <name>  one host's drill-down JSON, unavailable, or error:
#                              {system, metrics, failed, smart}, where metrics
#                              is the last hour (get_system_metrics), failed the
#                              failed units (list_services Failed) and smart the
#                              host's disks (list_smart_devices). A part whose
#                              call failed is null.
#
# Every call is a read-only tools/call. The token is streamed on a file
# descriptor and never appears in argv, on disk or in the output.
set -euo pipefail
# A caller's shell tracing must never expose credentials.
set +x

token_file=${BESZEL_MCP_TOKEN_FILE:-}
if [[ -z "$token_file" || ! -f "$token_file" || ! -r "$token_file" || ! -s "$token_file" ]]; then
  printf 'unavailable\n'
  exit 0
fi

# mcp <request-json>: print the tool's decoded result JSON. Returns 10 when
# the hub is unreachable and 11 when it answered with an error.
mcp() {
  local response http_code body
  # Only the descriptor path appears in argv. Suppress transport errors so
  # stderr cannot become a second, unstructured output contract.
  if ! response=$(curl --disable --silent --max-time 10 \
    --request POST 'https://beszel-mcp.hummingbird-lake.ts.net/mcp' \
    --header @/dev/fd/3 \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json, text/event-stream' \
    --data "$1" \
    --write-out $'\n%{http_code}' \
    3< <(printf 'Authorization: Bearer '; tr -d '\r\n' < "$token_file"; printf '\n') 2>/dev/null); then
    return 10
  fi
  http_code=${response##*$'\n'}
  if [[ ! "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    return 11
  fi
  body=${response%$'\n'*}
  # MCP may return JSON or an SSE data frame. Decode the nested JSON string.
  # Never execute any field from the hub.
  printf '%s' "$body" | jq -Rsc '
    (try fromjson catch (
      split("\n") | map(select(startswith("data:")) | ltrimstr("data:") | ltrimstr(" ")) | join("\n") | fromjson
    ))
    | if .error != null or .result.isError == true then error("MCP error") else .result.content[0].text | fromjson end
  ' 2>/dev/null || return 11
}

request() {
  jq -nc --arg tool "$1" --argjson arguments "$2" \
    '{jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: $tool, arguments: $arguments}}'
}

case "${1:-}" in
  "")
    rc=0
    result=$(mcp "$(request list_systems '{}')") || rc=$?
    if [[ $rc -eq 10 ]]; then printf 'unavailable\n'; exit 0; fi
    if [[ $rc -ne 0 ]]; then printf 'error\n'; exit 0; fi
    # Validate the display-data boundary.
    if ! systems=$(printf '%s' "$result" | jq -c '
      .systems
      | if type == "array" and all(.[]; type == "object" and (.name | type == "string") and (.status | IN("up", "down", "paused", "pending")))
        then . else error("Invalid systems") end
    ' 2>/dev/null); then
      printf 'error\n'
      exit 0
    fi
    printf '%s\n' "$systems"
    ;;
  host)
    name=${2:-}
    # A host name is display data from the hub; it only ever travels as a
    # JSON string built by jq, never through a shell.
    if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$ ]]; then
      printf 'error\n'
      exit 0
    fi
    codes=()
    rc=0
    metrics=$(mcp "$(request get_system_metrics "$(jq -nc --arg s "$name" '{system: $s, range: "1h", maxPoints: 30}')")" \
      | jq -c '[.points[]? | {t: .recordedAt, cpu: .cpuPercent, mem: .memoryPercent, disk: .diskPercent,
          net: ((.networkSentMbPerSec // 0) + (.networkReceivedMbPerSec // 0))}]' 2>/dev/null) || rc=$?
    [[ $rc -eq 0 && -n "$metrics" ]] || { codes+=("${rc:-11}"); metrics=null; }
    rc=0
    failed=$(mcp "$(request list_services "$(jq -nc --arg s "$name" '{system: $s, state: "Failed"}')")" \
      | jq -c '[.services[]? | .name | select(type == "string")]' 2>/dev/null) || rc=$?
    [[ $rc -eq 0 && -n "$failed" ]] || { codes+=("${rc:-11}"); failed=null; }
    rc=0
    smart=$(mcp "$(request list_smart_devices '{}')" \
      | jq -c --arg s "$name" '[.devices[]? | select(.system == $s)
          | {system, name, model, capacityGb, smartState, healthy, temperatureC, powerOnHours,
             attributes: [(.attributes // [])[] | select(.failing == true) | {name, failing}]}]' 2>/dev/null) || rc=$?
    [[ $rc -eq 0 && -n "$smart" ]] || { codes+=("${rc:-11}"); smart=null; }
    if [[ ${#codes[@]} -eq 3 ]]; then
      if [[ " ${codes[*]} " == *" 10 "* ]]; then printf 'unavailable\n'; else printf 'error\n'; fi
      exit 0
    fi
    jq -nc --arg system "$name" --argjson metrics "$metrics" --argjson failed "$failed" --argjson smart "$smart" \
      '{system: $system, metrics: $metrics, failed: $failed, smart: $smart}'
    ;;
  *)
    printf 'error\n'
    ;;
esac

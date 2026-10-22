#!/usr/bin/env bash
# Exercise the built server and CLI with empty, temporary data directories.
set -euo pipefail
app=${1:?Usage: logbook-smoke.sh APPLICATION}
root=$(mktemp -d -t logbook-smoke-XXXXXXXXXX)
pid=
cleanup() {
  local result=$? watchdog status
  trap - EXIT
  if [[ -n $pid ]]; then
    kill -INT "$pid" 2>/dev/null || true
    # Like the old smoke test, kill after five seconds; a forced kill alone
    # is not a failed assertion, but a nonzero graceful exit is.
    (sleep 5; touch "$root/forced-kill"; kill -KILL "$pid" 2>/dev/null || true) &
    watchdog=$!
    if wait "$pid"; then :; else
      status=$?
      if [[ $status != 137 || ! -e $root/forced-kill ]]; then result=1; fi
    fi
    kill "$watchdog" 2>/dev/null || true
    wait "$watchdog" 2>/dev/null || true
  fi
  if [[ $result != 0 ]]; then cat "$root/server.err" >&2; fi
  rm -rf "$root"
  exit "$result"
}
trap cleanup EXIT
# Let the kernel choose a free loopback port. The server logs the bound port.
: >"$root/server.log"
: >"$root/server.err"
NO_COLOR=1 "$app/bin/logbook-server" --port 0 \
  --data-dir "$root/data" --state-dir "$root/state" --inbox-dir "$root/inbox" \
  --gadgetbridge-export "$root/inbox/gadgetbridge/Gadgetbridge.db" \
  >"$root/server.log" 2>"$root/server.err" &
pid=$!
healthy=false
for ((attempt = 0; attempt < 100; attempt++)); do
  if ! kill -0 "$pid" 2>/dev/null; then
    echo 'server exited before becoming healthy' >&2
    exit 1
  fi
  if [[ $(<"$root/server.log") =~ Logbook\ listening\ on\ loopback.*port=([0-9]+) ]]; then
    url=http://127.0.0.1:${BASH_REMATCH[1]}
    if curl -fsS --max-time 1 "$url/healthz" >"$root/health.json" 2>/dev/null; then
      jq -se 'length == 1 and .[0] == {"status":"ok"}' "$root/health.json" >/dev/null
      healthy=true
      break
    fi
  fi
  sleep 0.1
done
if ! "$healthy"; then echo 'server did not become healthy' >&2; exit 1; fi
# Match truthiness of the original result assertion (including empty objects
# and arrays, which jq alone treats as true).
curl -fsS --max-time 5 "$url/rpc" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"metrics.list","params":{}}' \
  | jq -se 'length == 1 and (.[0].result | . != null and . != false and . != 0 and . != "" and . != [] and . != {})' >/dev/null
"$app/bin/logbook" --url "$url" status | jq -se 'length == 1 and (.[0] | type == "array")' >/dev/null
[[ -f $app/bin/logbook-tsnet ]]
echo 'PASS: built loopback server health, metrics RPC, and CLI status; no tailnet join'

#!/usr/bin/env bash
# All-or-nothing transport validation. Never accept green from a failed SSH
# command, an incomplete probe, or a stale/future sample.
set -uo pipefail
probe=$1
shift
now=${STORAGE_HEALTH_NOW:-$(date +%s)}
if [ "$#" -eq 0 ]; then
  printf 'configuration\tunreachable\tno storage hosts configured\t%s\n' "$now"
  exit 1
fi
for target in "$@"; do
  host=${target#*@}
  output=$(timeout 30 ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=8 \
    -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
    "$target" bash -s -- "$host" <"$probe" 2>/dev/null)
  code=$?
  valid=1
  complete=0
  rows=0
  timestamp=
  while IFS=$'\t' read -r level message extra; do
    if [ "$complete" -ne 0 ] || [ -n "$extra" ] || [ -z "$message" ]; then valid=0; fi
    case "$level" in
      ok | warn | bad) rows=$((rows + 1)) ;;
      complete)
        complete=$((complete + 1))
        timestamp=$message
        [[ "$timestamp" =~ ^[0-9]{10}$ ]] || valid=0
        ;;
      *) valid=0 ;;
    esac
  done <<<"$output"
  if [ "$code" -ne 0 ] || [ "$valid" -ne 1 ] || [ "$complete" -ne 1 ] || [ "$rows" -eq 0 ]; then
    printf '%s\tunreachable\tincomplete or failed SSH probe (exit %s)\t%s\n' "$host" "$code" "$now"
  elif [ "$((now - timestamp))" -gt 120 ] || [ "$((timestamp - now))" -gt 120 ]; then
    printf '%s\tunreachable\tprobe timestamp stale or clock differs\t%s\n' "$host" "$now"
  else
    while IFS=$'\t' read -r level message; do
      [ "$level" != complete ] || continue
      printf '%s\t%s\t%s\t%s\n' "$host" "$level" "$message" "$timestamp"
    done <<<"$output"
  fi
done

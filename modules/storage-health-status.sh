#!/usr/bin/env bash
# Runs the storage health probe on each server and prints one
# "host<TAB>level<TAB>message" line per finding, in the order given.
# Levels: ok, warn, bad, or unreachable when SSH gives no answer.
# Usage: storage-health-status PROBE user@host...
set -uo pipefail
probe=$1
shift

for target in "$@"; do
  host=${target#*@}
  # ConnectTimeout covers a dead host; timeout covers one that hangs later.
  output=$(timeout 25 ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=8 \
    -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
    "$target" bash -s <"$probe" 2>/dev/null)
  code=$?
  printed=0
  while IFS=$'\t' read -r level message; do
    case "$level" in
      ok | warn | bad)
        printf '%s\t%s\t%s\n' "$host" "$level" "$message"
        printed=1
        ;;
    esac
  done <<<"$output"
  if [ "$printed" -eq 0 ]; then
    printf '%s\tunreachable\tno answer over SSH (exit %s)\n' "$host" "$code"
  fi
done

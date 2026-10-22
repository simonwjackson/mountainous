#!/usr/bin/env bash
# Publish a complete SQLite export without exposing simon's home to Logbook.
# The destination directory must be root-owned and not writable by Logbook.
publish() (
  set -euo pipefail
  local source=$1 destination=$2 owner=$3 temporary=$2.tmp
  local before after size mode integrity uri
  local -a metadata
  # shellcheck disable=SC2329 # Invoked by the EXIT trap.
  cleanup() {
    local status=$?
    trap - EXIT
    rm -f -- "$temporary" || status=1
    if ((status != 0)); then
      echo 'Gadgetbridge export unavailable, incomplete, or changed; retrying' >&4
      exit 1
    fi
  }
  trap cleanup EXIT
  # fd 4 preserves stderr for cleanup's fixed message only. Suppress details.
  exec 2>/dev/null
  rm -f -- "$temporary"
  before=$(stat -c '%f %d %i %s %y %z' -- "$source")
  read -r -a metadata <<<"$before"
  mode=${metadata[0]}
  size=${metadata[3]}
  # stat does not follow symlinks. Inspect the mode from the same stat as size.
  (( (16#$mode & 0170000) == 0100000 && size > 0 ))
  # Exclusive creation, 0600, and at most the observed size in 1 MiB chunks.
  # nofollow/nonblock also protect against a symlink/FIFO swapped in after stat.
  (umask 077; set -o noclobber; : >"$temporary")
  dd if="$source" of="$temporary" bs=1M count="$size" \
    iflag=nofollow,nonblock,count_bytes,fullblock status=none
  [[ $(stat -c %s -- "$temporary") == "$size" ]]
  chown -- "$owner" "$temporary"
  chmod 0600 "$temporary"
  sync -- "$temporary"
  after=$(stat -c '%f %d %i %s %y %z' -- "$source")
  [[ $before == "$after" ]]
  # immutable avoids journal writes/locking. Check precisely the bytes to publish.
  uri=${temporary//%/%25}
  uri=${uri//\?/%3F}
  uri=${uri//#/%23}
  integrity=$(sqlite3 "file:$uri?mode=ro&immutable=1" 'PRAGMA quick_check;')
  [[ $integrity == ok ]]
  mv -fT -- "$temporary" "$destination"
  sync -- "$(dirname -- "$destination")"
) 4>&2

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  publish "$1" "$2" logbook:logbook
fi

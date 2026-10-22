#!/usr/bin/env bash
# Exercise the real bridge with SQLite files in an unprivileged temporary home.
set -euo pipefail
# shellcheck source=../modules/logbook-export.sh
source "${1:?Usage: test_logbook_export.sh BRIDGE_SOURCE}"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
source_db=$root/source.db
target=$root/Gadgetbridge.db
owner=$(id -u):$(id -g)
assert() { "$@" || { printf 'FAIL: %s\n' "$*" >&2; exit 1; }; }
reject() {
  local status=0
  # Do not put publish in an if/|| list: that disables its errexit checks.
  (set +e; publish "$source_db" "$target" "$owner"; exit "$?") >"$root/out" 2>"$root/error" &
  local child=$! watchdog
  (sleep 5; kill -KILL "$child" 2>/dev/null || true) &
  watchdog=$!
  wait "$child" || status=$?
  kill "$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  assert test "$status" = 1
  assert grep -qx 'Gadgetbridge export unavailable, incomplete, or changed; retrying' "$root/error"
  assert cmp "$target" "$root/last-good.db"
  assert test ! -e "$target.tmp"
}
sqlite3 "$source_db" 'CREATE TABLE samples(value INTEGER); INSERT INTO samples VALUES (1);'
publish "$source_db" "$target" "$owner"
original_inode=$(stat -c %i "$target")
assert test "$(stat -c %a "$target")" = 600
assert test "$(stat -c %u:%g "$target")" = "$owner"
assert cmp "$source_db" "$target"
sqlite3 "$source_db" 'INSERT INTO samples VALUES (2);'
publish "$source_db" "$target" "$owner"
assert test "$(stat -c %i "$target")" != "$original_inode"
assert test "$(sqlite3 "$target" 'SELECT value FROM samples;')" = $'1\n2'
cp "$target" "$root/last-good.db"
: >"$source_db"
reject
printf 'incomplete SQLite export' >"$source_db"
reject
head -c 100 "$target" >"$source_db"
reject
rm "$source_db"
ln -s "$target" "$source_db"
reject
rm "$source_db"
mkfifo "$source_db"
reject
rm "$source_db"
mkdir "$source_db"
reject
rmdir "$source_db"
reject # Missing source.

# Instrument the real copy command at its boundary. The bytes still come from
# coreutils dd; change the filesystem before the bridge rechecks stability.
cp "$target" "$source_db"
# shellcheck disable=SC2329 # Called by publish from the sourced bridge.
dd() { command dd "$@"; touch -m -d '2000-01-01 UTC' "$source_db"; }
reject
unset -f dd
assert cmp "$source_db" "$target"

# A copy whose bytes fail SQLite validation must never replace the snapshot.
# shellcheck disable=SC2329 # Called by publish from the sourced bridge.
dd() { command dd "$@"; printf corrupt >"$target.tmp"; }
reject
unset -f dd

# Exercise nofollow/nonblock on replacement after the initial regular-file stat.
# shellcheck disable=SC2329 # Called by publish from the sourced bridge.
dd() { rm "$source_db"; ln -s "$target" "$source_db"; command dd "$@"; }
reject
unset -f dd
rm "$source_db"
cp "$target" "$source_db"
# shellcheck disable=SC2329 # Called by publish from the sourced bridge.
dd() { rm "$source_db"; mkfifo "$source_db"; command dd "$@"; }
reject
unset -f dd

# URI punctuation in a destination is a path, not SQLite URI parameters.
publish "$target" "$root/snapshot ?#%.db" "$owner"
assert cmp "$target" "$root/snapshot ?#%.db"

# Check production CLI failure status without requiring a logbook account.
status=0
bash "${1}" "$root/missing.db" "$target" 2>"$root/error" || status=$?
assert test "$status" = 1
assert cmp "$target" "$root/last-good.db"
assert test ! -e "$target.tmp"
echo 'PASS: atomic snapshot, metadata, rejected exports, stable source, and cleanup'

#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils systemd
# On Rakku or Yari, as root: run one switch or rollback script as a transient
# systemd service (systemd-run --wait --collect), so a dropped SSH session
# cannot kill it in the middle of a switch or an automatic rollback. This
# client follows the unit's journal and returns its exit code. If the session
# drops, the unit carries on: read `journalctl -u UNIT -o cat` afterwards.
# Usage: pace2-launch.sh NAME SCRIPT [ARG...]
# The unit name is fixed per step (pace2-NAME), so systemd-run refuses a
# second run of the same step while the first is still active.
set -uo pipefail
name=$1
shift
unit="pace2-$name"
since=$(date +%s)
echo "running as $unit.service; if this session drops: journalctl -u $unit --since @$since -o cat"
journalctl -u "$unit" --since "@$since" -f -o cat --no-pager &
follower=$!
# The scripts use nix-shell shebangs, so they need the session's PATH and NIX_PATH.
systemd-run --unit "$unit" --wait --collect --quiet --service-type=exec \
  --setenv=PATH="$PATH" --setenv=NIX_PATH="${NIX_PATH:-}" \
  -p StandardOutput=journal -p StandardError=journal "$@"
rc=$?
sleep 2
kill "$follower" 2>/dev/null
wait "$follower" 2>/dev/null
echo "$unit.service exited $rc"
exit "$rc"

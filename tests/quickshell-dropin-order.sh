#!/usr/bin/env bash
# Exercise systemd's own drop-in loader against an offline root, never a live unit.
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
for prefix in etc run usr/lib; do
  mkdir -p "$work/$prefix/systemd/user/quickshell.service.d"
done
printf '[Service]\nExecStart=/bin/true\nKillMode=control-group\n' > "$work/usr/lib/systemd/user/quickshell.service"
printf '[Service]\nKillMode=mixed\n' > "$work/etc/systemd/user/quickshell.service.d/overrides.conf"
printf '[Service]\nKillMode=process\n' > "$work/run/systemd/user/quickshell.service.d/deploy-3-preserve-apps.conf"
merged() { systemd-analyze --root="$work" cat-config systemd/user/quickshell.service; }
last_mode() { awk '/^KillMode=/ {mode=$0} END {print mode}'; }
# Different basenames sort globally: overrides.conf follows deploy-3-*.conf.
test "$(merged | last_mode)" = KillMode=mixed
# Only identical basenames use directory priority: /etc shadows /run.
printf '[Service]\nKillMode=process\n' > "$work/run/systemd/user/quickshell.service.d/overrides.conf"
test "$(merged | last_mode)" = KillMode=mixed
if merged | grep -Fq "$work/run/systemd/user/quickshell.service.d/overrides.conf"; then
  echo 'same-name /run override incorrectly shadowed /etc' >&2
  exit 1
fi
# Install this before the switch, not after Hjem restarts Quickshell.
printf '[Service]\nKillMode=process\n' > "$work/run/systemd/user/quickshell.service.d/zz-deploy-preserve-apps.conf"
test "$(merged | last_mode)" = KillMode=process
printf 'QUICKSHELL_DROPIN_ORDER_PASSED: mixed wins original names; late runtime override preserves legacy apps\n'

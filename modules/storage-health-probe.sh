#!/usr/bin/env bash
# Read-only storage and service health, run on a server over SSH as an
# unprivileged user. Prints one "level<TAB>message" line per finding.
# Levels: bad (storage at risk), warn (other trouble), ok (nothing found).
# The roots are overridable only so tests/test_storage_health.py can fake them.
set -u
etc=${STORAGE_HEALTH_ETC:-/etc}
srv=${STORAGE_HEALTH_SRV:-/srv}
bcachefs_root=${STORAGE_HEALTH_BCACHEFS:-/sys/fs/bcachefs}
now=${STORAGE_HEALTH_NOW:-$(date +%s)}
sync_max_hours=36
cache_warn=60
cache_bad=75
issues=0

say() {
  printf '%s\t%s\n' "$1" "$2"
  issues=$((issues + 1))
}

# Every failed unit. Units that guard stored data count as bad.
while read -r unit _; do
  [ -n "$unit" ] || continue
  case "$unit" in
    *snapraid* | *-cache-mover* | *-mergerfs-* | bcachefs* | media-library-mover* | srv-*.mount | net-*.mount)
      say bad "$unit failed" ;;
    *) say warn "$unit failed" ;;
  esac
done < <(systemctl --failed --no-legend --plain 2>/dev/null)

# SnapRAID pools from the disk-array feature: /etc/snapraid-<pool>.conf.
for conf in "$etc"/snapraid-*.conf; do
  [ -e "$conf" ] || continue
  pool=${conf##*/snapraid-}
  pool=${pool%.conf}

  for disk in "$srv/shores/$pool"/*/; do
    [ -d "$disk" ] || continue
    disk=${disk%/}
    mountpoint -q "$disk" || say bad "$pool disk ${disk##*/} is not mounted"
  done

  # A sync that has nothing to do may not rewrite the content file, so the
  # journal, not a file time, records the last successful sync.
  last=$(journalctl -u "$pool-snapraid-sync.service" --since "-7 days" -o short-unix --no-pager 2>/dev/null |
    grep 'Finished SnapRAID Sync' | tail -n 1 | cut -d' ' -f1 | cut -d. -f1)
  if [ -z "$last" ]; then
    say bad "$pool: no successful SnapRAID sync in 7 days"
  else
    hours=$(((now - last) / 3600))
    if [ "$hours" -gt "$sync_max_hours" ]; then
      say bad "$pool: last SnapRAID sync ${hours} h ago"
    fi
  fi

  if [ -d "$srv/cache/$pool" ]; then
    used=$(df --output=pcent "$srv/cache/$pool" 2>/dev/null | tail -n 1 | tr -dc '0-9')
    if [ -n "$used" ] && [ "$used" -ge "$cache_bad" ]; then
      say bad "$pool NVMe cache ${used}% full, no parity"
    elif [ -n "$used" ] && [ "$used" -ge "$cache_warn" ]; then
      say warn "$pool NVMe cache ${used}% full, no parity"
    fi
  fi
done

# Every mounted bcachefs filesystem: member state and lifetime I/O errors.
for fs in "$bcachefs_root"/*/; do
  [ -d "$fs" ] || continue
  for dev in "$fs"dev-*/; do
    [ -d "$dev" ] || continue
    label=$(cat "$dev/label" 2>/dev/null)
    [ -n "$label" ] || label=${dev%/}
    label=${label##*/}
    state=$(sed -n 's/.*\[\([a-z]*\)\].*/\1/p' "$dev/state" 2>/dev/null)
    if [ -n "$state" ] && [ "$state" != rw ]; then
      say bad "bcachefs $label is $state"
    fi
    # sysfs writes "checksum:175" with no space, so split on the colon.
    errors=$(awk -F: '/IO errors since filesystem creation/ { on = 1; next }
      /IO errors/ { on = 0 }
      on && /:/ { sum += $2 }
      END { print sum + 0 }' "$dev/io_errors" 2>/dev/null)
    if [ -n "$errors" ] && [ "$errors" -gt 0 ]; then
      say warn "bcachefs $label: $errors I/O errors since creation"
    fi
  done
done

if [ "$issues" -eq 0 ]; then
  printf 'ok\tall checks passed\n'
fi
exit 0

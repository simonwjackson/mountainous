#!/usr/bin/env bash
# Read-only probe. A terminal completion record makes partial SSH output invalid.
# Root overrides are the deterministic filesystem/command fixture seam.
set -uo pipefail
export LC_ALL=C
etc=${STORAGE_HEALTH_ETC:-/etc}
srv=${STORAGE_HEALTH_SRV:-/srv}
bcachefs_root=${STORAGE_HEALTH_BCACHEFS:-/sys/fs/bcachefs}
now=${STORAGE_HEALTH_NOW:-$(date +%s)}
profile=${1:-unknown}
profile=${profile%%.*}
state_root=${STORAGE_HEALTH_STATE:-/var/lib/disk-array}
run_root=${STORAGE_HEALTH_RUN:-/run}
# Both deployed scrub timers are monthly. Allow a 31-day month plus nine
# days of scheduling/maintenance grace; sync remains a separate 36h policy.
scrub_max_hours=$((40 * 24))
issues=0
say() { printf '%s\t%s\n' "$1" "$2"; issues=$((issues + 1)); }

if failed=$(systemctl --failed --no-legend --plain 2>/dev/null); then
  while read -r unit _; do
    [ -n "$unit" ] || continue
    case "$unit" in
      *snapraid* | *-cache-mover* | *-mergerfs-* | bcachefs* | media-* | srv-*.mount | net-*.mount)
        say bad "$unit failed" ;;
      *) say warn "$unit failed" ;;
    esac
  done <<<"$failed"
else
  say warn 'failed-unit query unavailable'
fi

# Compare mounted identity to the configured source, not directory existence.
check_mount() {
  local path=$1 actual expected
  if [ ! -d "$path" ] || ! mountpoint -q "$path"; then
    say bad "$path is missing or not mounted"
    return
  fi
  actual=$(findmnt -rn -M "$path" -o UUID 2>/dev/null) || actual=
  expected=$(findmnt --fstab --evaluate -rn -M "$path" -o UUID 2>/dev/null) || expected=
  # A multi-device btrfs pool can report a different member path than fstab.
  # Compare filesystem UUIDs, not whichever member the kernel chose first.
  if [ -z "$actual" ] || [ -z "$expected" ]; then
    say warn "$path mount identity unavailable"
  elif [ "$actual" != "$expected" ]; then
    say bad "$path mounted filesystem UUID differs from fstab"
  fi
}

freshness() {
  local unit=$1 label=$2 max_hours=$3 log last age
  # MESSAGE_ID identifies systemd's successful unit completion, independent of
  # translated descriptions. Failed/started jobs cannot refresh this timestamp.
  if ! log=$(journalctl -u "$unit" MESSAGE_ID=39f53479d3a045ac8e11786248231fbf --since '-60 days' -o short-unix --no-pager 2>/dev/null); then
    say warn "$label history unreadable"
    return
  fi
  last=$(printf '%s\n' "$log" | awk '/^[0-9]+\.[0-9]+ / {split($1,t,"."); last=t[1]} END {print last}')
  if [[ ! "$last" =~ ^[0-9]+$ ]]; then
    say bad "$label: no recorded success in 60 days"
    return
  fi
  age=$((now - last))
  if [ "$age" -lt -120 ]; then
    say warn "$label: success timestamp is in the future"
  elif [ "$age" -gt "$((max_hours * 3600))" ]; then
    say bad "$label: last success $((age / 3600)) h ago"
  fi
}

pools=0
[ "$profile" != zao ] || [ -r "$etc/snapraid-towada.conf" ] || say bad 'expected towada SnapRAID configuration missing or unreadable'
for conf in "$etc"/snapraid-*.conf; do
  [ -e "$conf" ] || continue
  pools=$((pools + 1))
  pool=${conf##*/snapraid-}; pool=${pool%.conf}
  if [ ! -r "$conf" ]; then say bad "$pool configuration unreadable"; continue; fi
  # Parse expected data AND parity roots from configuration. A deleted mount
  # directory must not disappear from discovery and turn the result green.
  roots=$(awk '$1 == "data" || $1 == "disk" {print $3} $1 ~ /^([2-6]-)?parity$/ {sub(/\/[^/]+$/, "", $2); print $2}' "$conf" | sort -u)
  if [ -z "$roots" ]; then say bad "$pool has no configured data/parity paths"; fi
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    check_mount "$path"
  done <<<"$roots"
  if [ "$profile" = zao ] && [ "$pool" = towada ]; then
    for disk in 00 01 02 03 04; do
      path="$srv/shores/towada/$disk"
      if ! grep -Fxq "$path" <<<"$roots"; then say bad "towada expected disk $disk absent from configuration"; fi
    done
  fi
  freshness "$pool-snapraid-sync.service" "$pool SnapRAID sync" 36
  freshness "$pool-snapraid-scrub.service" "$pool SnapRAID scrub" "$scrub_max_hours"
  cache="$srv/cache/$pool"
  check_mount "$cache"
  if [ -d "$cache" ] && mountpoint -q "$cache"; then
    if usage=$(df --output=pcent "$cache" 2>/dev/null) && [[ "$usage" =~ ^[[:space:]]*Use%[[:space:]]+([0-9]+)%[[:space:]]*$ ]] && [ "${BASH_REMATCH[1]}" -le 100 ]; then
      used=${BASH_REMATCH[1]}
      if [ "$used" -ge 90 ]; then say bad "$pool shared cache filesystem ${used}% used"
      elif [ "$used" -ge 80 ]; then say warn "$pool shared cache filesystem ${used}% used"; fi
    else
      say warn "$pool shared cache filesystem usage unavailable"
    fi
  fi
  # The public mover summary describes its last batch, never a tree scan or
  # live backlog. Null/missing counts must not become zero.
  summary="$state_root/$pool/status.json"
  if [ ! -r "$summary" ] || ! command -v jq >/dev/null; then
    say warn "$pool cache backlog/protection unknown (summary unavailable)"
  elif [ "$(stat -c %s "$summary" 2>/dev/null || echo 65537)" -gt 65536 ]; then
    say warn "$pool cache summary invalid"
  elif fields=$(jq -er '
      def count: . == null or (type == "number" and . >= 0 and floor == .);
      select(.schemaVersion == 1 and (.observedAt | type == "number" and floor == .)
        and (.phase | type == "string" and test("^[a-zA-Z0-9_-]{1,64}$"))
        and (.pendingFiles | count) and (.pendingBytes | count)
        and (.protectedFiles | count) and (.releasedFiles | count)
        and (.lastError == null or (.lastError | type == "string" and test("^[a-zA-Z0-9_-]{1,64}$"))))
      | [.observedAt, .phase, (.pendingFiles // "unknown"), (.pendingBytes // "unknown"),
         (.protectedFiles // "unknown"), (.releasedFiles // "unknown"), (.lastError // "none")] | @tsv
    ' "$summary" 2>/dev/null); then
    IFS=$'\t' read -r observed phase pending_files pending_bytes protected released last_error <<<"$fields"
    if [ "$((now - observed))" -gt 129600 ] || [ "$((observed - now))" -gt 120 ]; then
      say warn "$pool cache summary stale or clock differs"
    fi
    say warn "$pool last batch: $phase; protected $protected, released $released files; backlog $pending_files files / $pending_bytes bytes"
    [ "$last_error" = none ] || say bad "$pool cache mover: $last_error"
  else
    say warn "$pool cache summary invalid"
  fi
  say warn "$pool automatic source release held; cache can fill"

done

mounted=$(findmnt -rn -t bcachefs -o UUID 2>/dev/null) || mounted=
if [ "$profile" = unzen ]; then
  expected_uuid=e5f61013-d6f5-260d-9883-4dda26b2c293
  grep -Fxq "$expected_uuid" <<<"$mounted" || say bad 'expected Unzen bcachefs filesystem is not mounted'
  [ -d "$bcachefs_root/$expected_uuid" ] || say bad 'expected Unzen bcachefs sysfs probes missing'
  freshness bcachefs-scrub-root.service 'bcachefs scrub' "$scrub_max_hours"
fi
filesystems=0
for fs in "$bcachefs_root"/*/; do
  [ -d "$fs" ] || continue
  filesystems=$((filesystems + 1))
  labels=' '
  members=0
  for dev in "$fs"dev-*/; do
    [ -d "$dev" ] || continue
    members=$((members + 1))
    label=$(cat "$dev/label" 2>/dev/null) || label=
    if [ -z "$label" ]; then say warn 'bcachefs member label unreadable'; label=${dev%/}; fi
    labels+="$label "
    state=$(sed -n 's/.*\[\([a-z]*\)\].*/\1/p' "$dev/state" 2>/dev/null) || state=
    if [ -z "$state" ]; then say warn "bcachefs $label state unreadable"
    elif [ "$state" != rw ]; then say bad "bcachefs $label is $state"; fi
    errors=$(awk -F: '/IO errors since filesystem creation/ {on=1; seen=1; next}
      /IO errors/ {on=0}
      on && /:/ {if ($2 !~ /^[[:space:]]*[0-9]+[[:space:]]*$/) exit 1; sum+=$2; count++}
      END {if (!seen || count != 3) exit 1; print sum+0}' "$dev/io_errors" 2>/dev/null) || errors=
    if [[ ! "$errors" =~ ^[0-9]+$ ]]; then say warn "bcachefs $label I/O counters unreadable"
    elif [ "$errors" -gt 0 ]; then say warn "bcachefs $label: $errors I/O errors since creation"; fi
  done
  [ "$members" -gt 0 ] || say bad 'bcachefs has no readable members'
  if [ "$profile" = unzen ]; then
    for label in onboard.sn770 card.samsung card.sabrent; do
      [[ "$labels" == *" $label "* ]] || say bad "expected bcachefs member $label missing"
    done
    [ "$members" -eq 3 ] || say bad 'Unzen bcachefs member count differs from expected three'
  fi
done
if [ -n "$mounted" ] && [ "$filesystems" -eq 0 ]; then say bad 'mounted bcachefs has no readable sysfs probes'; fi
if [ "$pools" -eq 0 ] && [ "$filesystems" -eq 0 ]; then say warn 'no storage topology could be checked'; fi
if [ "$profile" = unzen ]; then
  [ ! -e "$run_root/media-storage-blocked" ] || say warn 'media processing held after storage failure; operator recovery required'
  if ! command -v media-storage-health >/dev/null; then
    say warn 'media view health probe unavailable'
  elif ! timeout --kill-after=2s 20s media-storage-health >/dev/null 2>&1; then
    say bad 'media views unreadable or not mounted'
  fi
fi
[ "$issues" -ne 0 ] || printf 'ok\tall checks passed\n'
printf 'complete\t%s\n' "$now"

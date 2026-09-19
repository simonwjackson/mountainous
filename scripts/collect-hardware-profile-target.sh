#!/usr/bin/env nix-shell
#!nix-shell -i bash -p dmidecode usbutils efibootmgr ethtool alsa-utils pciutils smartmontools util-linux edid-decode
set -euo pipefail

OUTDIR="/tmp/target-hardware-profile"
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

log() {
  echo "=== $1 ===" >> "$OUTDIR/summary.txt"
}

run_cmd() {
  local name="$1"
  shift
  local outfile="$OUTDIR/$name.txt"
  echo "--- $name ---" >> "$OUTDIR/summary.txt"
  if command -v "$1" >/dev/null 2>&1; then
    "$@" > "$outfile" 2>&1 || true
    head -n 25 "$outfile" >> "$OUTDIR/summary.txt"
    if [ "$(wc -l < "$outfile")" -gt 25 ]; then
      echo "  [... $(wc -l < "$outfile") total lines in $name.txt ...]" >> "$OUTDIR/summary.txt"
    fi
  else
    echo "command not found: $1" > "$outfile"
    echo "command not found: $1" >> "$OUTDIR/summary.txt"
  fi
  echo "" >> "$OUTDIR/summary.txt"
}

echo "Collecting hardware profile on $(hostname) at $(date -u)..." > "$OUTDIR/summary.txt"
echo "" >> "$OUTDIR/summary.txt"

# 1. System & DMI
log "DMI / System Identity"
mkdir -p "$OUTDIR/dmi"
for f in /sys/class/dmi/id/*; do
  if [ -f "$f" ]; then
    val=$(cat "$f" 2>/dev/null || echo "<unreadable>")
    echo "$(basename "$f"): $val" >> "$OUTDIR/dmi/sysfs_dmi.txt"
  fi
done
cat "$OUTDIR/dmi/sysfs_dmi.txt" >> "$OUTDIR/summary.txt"
echo "" >> "$OUTDIR/summary.txt"

run_cmd "hostnamectl" hostnamectl
run_cmd "dmidecode_system" dmidecode -t system
run_cmd "dmidecode_bios" dmidecode -t bios
run_cmd "dmidecode_baseboard" dmidecode -t baseboard
run_cmd "dmidecode_chassis" dmidecode -t chassis
run_cmd "dmidecode_full" dmidecode

# 2. CPU & Topology
log "Processor"
run_cmd "lscpu" lscpu
cat /proc/cpuinfo > "$OUTDIR/cpuinfo.txt" 2>&1 || true

mkdir -p "$OUTDIR/cpufreq"
for f in /sys/devices/system/cpu/cpu0/cpufreq/*; do
  if [ -f "$f" ]; then
    echo "$(basename "$f"): $(cat "$f" 2>/dev/null)" >> "$OUTDIR/cpufreq/cpu0_cpufreq.txt"
  fi
done
[ -f "$OUTDIR/cpufreq/cpu0_cpufreq.txt" ] && cat "$OUTDIR/cpufreq/cpu0_cpufreq.txt" >> "$OUTDIR/summary.txt"

mkdir -p "$OUTDIR/vulnerabilities"
for f in /sys/devices/system/cpu/vulnerabilities/*; do
  if [ -f "$f" ]; then
    echo "$(basename "$f"): $(cat "$f" 2>/dev/null)" >> "$OUTDIR/vulnerabilities/vulnerabilities.txt"
  fi
done
[ -f "$OUTDIR/vulnerabilities/vulnerabilities.txt" ] && cat "$OUTDIR/vulnerabilities/vulnerabilities.txt" >> "$OUTDIR/summary.txt"

# 3. Memory
log "Memory"
run_cmd "free" free -h
cat /proc/meminfo > "$OUTDIR/meminfo.txt" 2>&1 || true
run_cmd "dmidecode_memory" dmidecode -t memory

# 4. PCI Bus
log "PCI Devices"
run_cmd "lspci_brief" lspci -nn
run_cmd "lspci_tree" lspci -tv
run_cmd "lspci_verbose" lspci -nn -vvv

# 5. USB Devices
log "USB Devices"
run_cmd "lsusb" lsusb
run_cmd "lsusb_tree" lsusb -t
run_cmd "lsusb_verbose" lsusb -v

# 6. Block Devices & Storage
log "Storage & Block Devices"
run_cmd "lsblk_tree" lsblk -o NAME,KNAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,UUID,PARTUUID,MOUNTPOINTS,ROTA,TRAN,MODEL,VENDOR,REV
run_cmd "lsblk_json" lsblk -J -o NAME,KNAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,UUID,PARTUUID,MOUNTPOINTS,ROTA,TRAN,MODEL,VENDOR,REV
run_cmd "fdisk_mmcblk1" fdisk -l /dev/mmcblk1
run_cmd "fdisk_sda" fdisk -l /dev/sda
run_cmd "findmnt" findmnt -l
cat /proc/mounts > "$OUTDIR/mounts.txt" 2>&1 || true

mkdir -p "$OUTDIR/emmc"
if [ -d /sys/block/mmcblk1/device ]; then
  for f in /sys/block/mmcblk1/device/*; do
    if [ -f "$f" ]; then
      val=$(cat "$f" 2>/dev/null || echo "<unreadable>")
      echo "$(basename "$f"): $val" >> "$OUTDIR/emmc/mmcblk1_props.txt"
    fi
  done
  cat "$OUTDIR/emmc/mmcblk1_props.txt" >> "$OUTDIR/summary.txt"
fi

# 7. Graphics & Display
log "Graphics & DRM"
run_cmd "dri_nodes" ls -la /dev/dri/
mkdir -p "$OUTDIR/drm"
for card in /sys/class/drm/card* /sys/class/drm/render*; do
  if [ -e "$card" ]; then
    echo "$(basename "$card"):" >> "$OUTDIR/drm/connectors.txt"
    if [ -f "$card/status" ]; then
      echo "  status: $(cat "$card/status" 2>/dev/null)" >> "$OUTDIR/drm/connectors.txt"
    fi
    if [ -f "$card/enabled" ]; then
      echo "  enabled: $(cat "$card/enabled" 2>/dev/null)" >> "$OUTDIR/drm/connectors.txt"
    fi
    if [ -f "$card/modes" ]; then
      echo "  modes: $(cat "$card/modes" 2>/dev/null | tr '\n' ' ')" >> "$OUTDIR/drm/connectors.txt"
    fi
    if [ -f "$card/edid" ] && [ -s "$card/edid" ]; then
      cp "$card/edid" "$OUTDIR/drm/$(basename "$card").edid" 2>/dev/null || true
    fi
  fi
done
[ -f "$OUTDIR/drm/connectors.txt" ] && cat "$OUTDIR/drm/connectors.txt" >> "$OUTDIR/summary.txt"

mkdir -p "$OUTDIR/backlight"
for bl in /sys/class/backlight/*; do
  if [ -d "$bl" ]; then
    echo "backlight $(basename "$bl"):" >> "$OUTDIR/backlight/backlights.txt"
    echo "  max_brightness: $(cat "$bl/max_brightness" 2>/dev/null)" >> "$OUTDIR/backlight/backlights.txt"
    echo "  actual_brightness: $(cat "$bl/actual_brightness" 2>/dev/null)" >> "$OUTDIR/backlight/backlights.txt"
    echo "  brightness: $(cat "$bl/brightness" 2>/dev/null)" >> "$OUTDIR/backlight/backlights.txt"
  fi
done
[ -f "$OUTDIR/backlight/backlights.txt" ] && cat "$OUTDIR/backlight/backlights.txt" >> "$OUTDIR/summary.txt"

# 8. Audio
log "Audio"
cat /proc/asound/cards > "$OUTDIR/asound_cards.txt" 2>&1 || true
cat /proc/asound/devices > "$OUTDIR/asound_devices.txt" 2>&1 || true
cat /proc/asound/pcm > "$OUTDIR/asound_pcm.txt" 2>&1 || true
run_cmd "aplay_l" aplay -l
run_cmd "arecord_l" arecord -l

mkdir -p "$OUTDIR/audio_codecs"
for c in /proc/asound/card*/codec*; do
  if [ -f "$c" ]; then
    cp "$c" "$OUTDIR/audio_codecs/$(basename "$(dirname "$c")")_$(basename "$c").txt" 2>/dev/null || true
  fi
done

# 9. Network
log "Network Interfaces"
run_cmd "ip_addr" ip -d addr show
run_cmd "ip_link" ip -d link show
run_cmd "ip_route" ip route show
run_cmd "rfkill" rfkill list

for iface in $(ip -o link show | awk -F': ' '{print $2}' | cut -d'@' -f1); do
  if [ "$iface" != "lo" ]; then
    run_cmd "ethtool_$iface" ethtool "$iface"
    run_cmd "ethtool_driver_$iface" ethtool -i "$iface"
  fi
done

# 10. Input Devices
log "Input Devices"
cat /proc/bus/input/devices > "$OUTDIR/input_devices.txt" 2>&1 || true
cat "$OUTDIR/input_devices.txt" >> "$OUTDIR/summary.txt"

mkdir -p "$OUTDIR/iio"
for dev in /sys/bus/iio/devices/iio:device*; do
  if [ -d "$dev" ]; then
    echo "iio $(basename "$dev") name: $(cat "$dev/name" 2>/dev/null)" >> "$OUTDIR/iio/iio_devices.txt"
  fi
done
[ -f "$OUTDIR/iio/iio_devices.txt" ] && cat "$OUTDIR/iio/iio_devices.txt" >> "$OUTDIR/summary.txt"

# 11. Power & Thermal
log "Power & Thermal"
mkdir -p "$OUTDIR/thermal"
for tz in /sys/class/thermal/thermal_zone*; do
  if [ -d "$tz" ]; then
    type=$(cat "$tz/type" 2>/dev/null || echo "unknown")
    temp=$(cat "$tz/temp" 2>/dev/null || echo "unknown")
    echo "$(basename "$tz") ($type): $temp mC" >> "$OUTDIR/thermal/thermal_zones.txt"
  fi
done
[ -f "$OUTDIR/thermal/thermal_zones.txt" ] && cat "$OUTDIR/thermal/thermal_zones.txt" >> "$OUTDIR/summary.txt"

mkdir -p "$OUTDIR/power_supply"
for ps in /sys/class/power_supply/*; do
  if [ -d "$ps" ]; then
    echo "power_supply $(basename "$ps"):" >> "$OUTDIR/power_supply/power_supply.txt"
    for prop in "$ps"/*; do
      if [ -f "$prop" ]; then
        echo "  $(basename "$prop"): $(cat "$prop" 2>/dev/null)" >> "$OUTDIR/power_supply/power_supply.txt"
      fi
    done
  fi
done
[ -f "$OUTDIR/power_supply/power_supply.txt" ] && cat "$OUTDIR/power_supply/power_supply.txt" >> "$OUTDIR/summary.txt"

# 12. EFI & Firmware
log "EFI & Firmware"
run_cmd "efibootmgr" efibootmgr -v
ls -la /sys/firmware/acpi/tables/ > "$OUTDIR/acpi_tables.txt" 2>&1 || true
ls -la /sys/firmware/efi/efivars/ > "$OUTDIR/efivars.txt" 2>&1 || true

# 13. Kernel & Logs
log "Kernel & Diagnostics"
run_cmd "uname" uname -a
cat /proc/cmdline > "$OUTDIR/cmdline.txt" 2>&1 || true
run_cmd "lsmod" lsmod
run_cmd "failed_units" systemctl --failed
dmesg > "$OUTDIR/dmesg.txt" 2>&1 || true
grep -i -E 'error|failed|fault|firmware|missing|warn' "$OUTDIR/dmesg.txt" > "$OUTDIR/dmesg_errors.txt" 2>&1 || true

# Package into tarball
cd /tmp
tar -czf /tmp/target-hardware-profile.tar.gz -C /tmp target-hardware-profile

echo "Profile collection complete. Summary written to $OUTDIR/summary.txt and archive at /tmp/target-hardware-profile.tar.gz"

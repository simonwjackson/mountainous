#!/usr/bin/env bash
# Dynamic fancontrol wrapper for GPD devices
# Finds hwmon devices by name to handle changing hwmon numbers across reboots

set -euo pipefail

# Find hwmon number by device name
find_hwmon() {
  local name="$1"
  for hwmon in /sys/class/hwmon/hwmon*; do
    if [[ -f "$hwmon/name" ]] && [[ "$(cat "$hwmon/name")" == "$name" ]]; then
      basename "$hwmon"
      return 0
    fi
  done
  echo "ERROR: Could not find hwmon device with name: $name" >&2
  return 1
}

# Get device path from hwmon
get_devpath() {
  local hwmon="$1"
  readlink -f "/sys/class/hwmon/$hwmon/device" | sed 's|/sys/||'
}

# Configuration
FAN_DEVICE="gpdfan"
TEMP_DEVICE="k10temp"
INTERVAL=3
MINTEMP=55
MAXTEMP=80
MINSTART=80
MINSTOP=60
MINPWM=0
MAXPWM=255

# Find devices
FAN_HWMON=$(find_hwmon "$FAN_DEVICE")
TEMP_HWMON=$(find_hwmon "$TEMP_DEVICE")

echo "Found $FAN_DEVICE at $FAN_HWMON"
echo "Found $TEMP_DEVICE at $TEMP_HWMON"

FAN_DEVPATH=$(get_devpath "$FAN_HWMON")
TEMP_DEVPATH=$(get_devpath "$TEMP_HWMON")

# Generate config
CONFIG_FILE=$(mktemp /tmp/fancontrol.XXXXXX)
trap "rm -f $CONFIG_FILE" EXIT

cat >"$CONFIG_FILE" <<EOF
INTERVAL=$INTERVAL
DEVPATH=$FAN_HWMON=$FAN_DEVPATH $TEMP_HWMON=$TEMP_DEVPATH
DEVNAME=$FAN_HWMON=$FAN_DEVICE $TEMP_HWMON=$TEMP_DEVICE
FCTEMPS=$FAN_HWMON/pwm1=$TEMP_HWMON/temp1_input
FCFANS=$FAN_HWMON/pwm1=$FAN_HWMON/fan1_input
MINTEMP=$FAN_HWMON/pwm1=$MINTEMP
MAXTEMP=$FAN_HWMON/pwm1=$MAXTEMP
MINSTART=$FAN_HWMON/pwm1=$MINSTART
MINSTOP=$FAN_HWMON/pwm1=$MINSTOP
MINPWM=$FAN_HWMON/pwm1=$MINPWM
MAXPWM=$FAN_HWMON/pwm1=$MAXPWM
EOF

echo "Generated fancontrol config:"
cat "$CONFIG_FILE"
echo ""
echo "Starting fancontrol..."

exec fancontrol "$CONFIG_FILE"

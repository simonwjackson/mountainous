# Saramonic BTW Bluetooth Microphone — Button Input

## Summary

The Saramonic BTW Bluetooth microphone exposes a button as a Linux input device via AVRCP (Audio/Video Remote Control Profile). The button press can be captured and used to trigger arbitrary actions on the host.

## Device Details

| Field | Value |
|-------|-------|
| **Device Name** | `Saramonic BTW (AVRCP)` |
| **Bus** | `0x5` |
| **Vendor** | `0x3e0` |
| **Product** | `0x301b` |
| **Input Event Node** | `/dev/input/event22` |
| **Sysfs** | `/devices/virtual/input/input57` |
| **Handlers** | `kbd event22` |
| **Bluetooth Address** | `F4:4E:FC:84:E6:61` |

> **Note:** The event node (`event22`) may change across reboots or reconnections. Use a udev rule or match by device name for a stable reference.

## Button Behavior

Pressing the button on the microphone emits:

- **Key code:** `KEY_PLAYCD` (code `200`)
- **Event type:** `EV_KEY` (type `1`)
- **Press:** `value 1` (key down), immediately followed by `value 0` (key up)

### Raw Event Example

```
Event: time 1773951859.487978, type 1 (EV_KEY), code 200 (KEY_PLAYCD), value 1
Event: time 1773951859.487978, -------------- SYN_REPORT ------------
Event: time 1773951859.497984, type 1 (EV_KEY), code 200 (KEY_PLAYCD), value 0
Event: time 1773951859.497984, -------------- SYN_REPORT ------------
```

## How to Monitor

Requires root access:

```bash
sudo evtest /dev/input/event22
```

Or find the device dynamically:

```bash
sudo evtest $(grep -l "Saramonic BTW" /sys/class/input/event*/device/name | sed 's|/sys/class/input/|/dev/input/|;s|/device/name||')
```

## Integration Notes (for STT/Dictation)

To use this button as a push-to-talk or dictation toggle:

1. **Listen for `KEY_PLAYCD`** on the Saramonic BTW input device
2. **On key down (`value 1`):** Start recording / activate STT
3. **On key up (`value 0`):** Stop recording / deactivate STT (or toggle on each press)

### Python Example (using `evdev`)

```python
from evdev import InputDevice, categorize, ecodes

# Find device by name for stability
import evdev
devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
dev = next(d for d in devices if "Saramonic BTW" in d.name)

print(f"Listening on {dev.path}: {dev.name}")
for event in dev.read_loop():
    if event.type == ecodes.EV_KEY and event.code == 200:  # KEY_PLAYCD
        if event.value == 1:
            print("Button PRESSED — start dictation")
        elif event.value == 0:
            print("Button RELEASED — stop dictation")
```

> **Permission:** Reading from `/dev/input/event*` requires root or membership in the `input` group.

## All Supported Key Codes

The AVRCP profile advertises these keys (though only `KEY_PLAYCD` was observed from the physical button):

| Key | Code |
|-----|------|
| KEY_PLAYCD | 200 |
| KEY_PAUSECD | 201 |
| KEY_NEXTSONG | 163 |
| KEY_PREVIOUSSONG | 165 |
| KEY_STOPCD | 166 |
| KEY_RECORD | 167 |
| KEY_REWIND | 168 |
| KEY_FASTFORWARD | 208 |
| KEY_VOLUMEUP | 115 |
| KEY_VOLUMEDOWN | 114 |
| KEY_MUTE | 113 |
| KEY_ENTER | 28 |
| KEY_UP/DOWN/LEFT/RIGHT | 103/108/105/106 |
| KEY_SELECT | 353 |
| KEY_MENU | 139 |
| KEY_INFO | 358 |
| KEY_POWER2 | 356 |
| KEY_RED/GREEN/YELLOW/BLUE | 398-401 |
| KEY_CHANNELUP/DOWN | 402/403 |
| + others | (F1-F9, 0-9, etc.) |

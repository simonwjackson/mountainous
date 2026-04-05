# Sleep/Hibernate Bug Report — yuki

**Host:** yuki (NixOS, Hyprland)  
**Investigated:** 2026-03-18 through 2026-03-24

Three separate incidents where sleep/hibernate behavior was wrong. Each has a different root cause, but they share a common theme: the sleep stack has no redundancy — when any single layer fails, there is no fallback.

---

## Incident 1 — Laptop never hibernated after undocking (Mar 18)

### What happened

Lid closed and dock disconnected at 13:23. Laptop stayed awake with screen off for 73 minutes until the lid was manually opened at 14:37.

### Timeline

| Time | Event |
|------|-------|
| 13:23:51 | Thunderbolt 4 dock disconnected |
| 13:23:52.095 | `hyprdynamicmonitors` fires `yuki-undock-suspend yukiInternal` |
| 13:23:52.472 | Second monitor state change (flicker during disconnect) |
| 13:23:52.503 | `hyprdynamicmonitors` **kills** `yuki-undock-suspend` (~0.4s) |
| 13:23:52 | `yuki-lid-state-watch` disables internal displays but does not schedule suspend |
| 14:37:14 | Lid opened — no suspend/hibernate ever occurred |

### Root cause

Two failures combined:

1. **`yuki-undock-suspend` killed by rapid monitor flicker.** The dock disconnect caused monitors to change state twice in 0.4 seconds. `hyprdynamicmonitors` killed the first callback to re-evaluate, but the script never reached its suspend-scheduling logic.

2. **`yuki-lid-state-watch` missed the transition.** Its 1-second polling caught `lidClosed=true` while `dpCount > 0` (still docked) in a prior cycle, writing `prevLidClosed=true`. When `dpCount` dropped to 0, the scheduling condition (`prevLidClosed != "true"`) was already false. The script handles "lid just closed while undocked" but not "lid already closed when dock disconnects."

### Gap

`yuki-lid-state-watch` never updates `prevDpCount` — it preserves the stale value from `yuki-undock-suspend`. It cannot detect dock state transitions independently.

---

## Incident 2 — Laptop never hibernated after closing lid (Mar 19)

### What happened

Lid closed at 16:18. Laptop stayed awake for 3 hours 51 minutes until the lid was opened at 20:09.

### Timeline

| Time | Event |
|------|-------|
| 15:50:24 | `nixos-rebuild switch` executed |
| 15:51:24 | Rebuild ran `systemctl restart user@1000.service` |
| 15:51:24 | Old user manager (PID 4447) killed — **all user services stopped** |
| 15:51:25 | New user manager (PID 513028) started as non-graphical session |
| 16:18:37 | Lid closed — nobody watching |
| 20:09:14 | Lid opened — laptop was awake the entire time |

### Root cause

`nixos-rebuild switch` restarted the systemd user manager. The new manager session (type "manager") has no graphical context, so `graphical-session.target` remained **inactive**. Every service bound to it was never restarted:

| Service | Binding | Status after rebuild |
|---------|---------|---------------------|
| `yuki-lid-state-watch` | `PartOf=graphical-session.target` | dead |
| `hyprdynamicmonitors` | `PartOf=graphical-session.target`, `Requires=graphical-session.target` | dead |
| `hypridle` | `PartOf=graphical-session.target`, `ConditionEnvironment=WAYLAND_DISPLAY` | dead |

Hyprland itself survived (direct child of login session, not the user manager), creating a split-brain state: the compositor was running but every service that depends on it was gone.

With all watchers dead and `logind` configured with `HandleLidSwitch=ignore`, nothing on the system could respond to a lid close.

---

## Incident 3 — Laptop hibernated while plugged in (Mar 24)

### What happened

Laptop was on AC power, plugged in, battery at 100%. After 15 minutes of idle it entered `suspend-then-hibernate` and eventually hibernated at ~11:03.

### Timeline

| Time | Event |
|------|-------|
| 10:26:36 | Firefox released 3 screensaver inhibit locks (video/audio stopped) |
| 10:33:13 | Last user input |
| 10:38:13 | 300s idle → hypridle turns DPMS off |
| 10:48:13 | 900s idle → hypridle runs `systemctl suspend-then-hibernate` |
| 11:03:14 | `HibernateDelaySec=15min` elapsed → system hibernates |
| 11:37:01 | System woken |

### Root cause

The hypridle hibernate listener has no power-state condition:

```ini
listener {
  on-timeout = systemctl suspend-then-hibernate
  timeout = 900
}
```

hypridle has no built-in concept of AC vs battery. It fires unconditionally after 900 seconds of idle. The laptop was confirmed on AC power throughout (ADP0/online=1, 120Hz refresh rate, battery fully charged).

### Evidence AC was connected

- `/sys/class/power_supply/ADP0/online` = 1
- Display at 120Hz (the AC rate; 60Hz is battery rate)
- `yuki-refresh-rate` never called `yuki-apply-display` (no power state change)
- Battery at 100%, state `fully-charged`

---

## Architecture Overview

The sleep stack on yuki has four layers, each with a narrow scope:

```
┌─────────────────────────────────────────────────────────┐
│ logind            HandleLidSwitch=ignore (disabled)      │
├─────────────────────────────────────────────────────────┤
│ yuki-undock-      Lid closed + dock disconnect           │
│ suspend           (callback from hyprdynamicmonitors)    │
├─────────────────────────────────────────────────────────┤
│ yuki-lid-state-   Lid close/open polling (1s interval)  │
│ watch             Schedules suspend with 5min buffer     │
├─────────────────────────────────────────────────────────┤
│ hypridle          Idle timeout → DPMS off (300s)         │
│                   Idle timeout → suspend-then-hibernate  │
│                   (900s, no power check)                 │
└─────────────────────────────────────────────────────────┘
```

Every layer can fail independently and there is no cross-layer fallback. `logind` — the only component that doesn't depend on `graphical-session.target` — is explicitly disabled.

---

## Recommended Fixes

### 1. `yuki-lid-state-watch`: detect dock disconnects while lid is closed

Add a condition for "lid was already closed and dock just disconnected." Also track `prevDpCount` properly.

```bash
# After the existing lid-close scheduling block:
if [ "$prevLidClosed" = "true" ] && [ "$lidClosed" = "true" ] \
   && [ "$dpCount" -eq 0 ] && [ "$prevDpCount" -gt 0 ]; then
  shouldScheduleSuspend="1"
  scheduledSuspendGeneration=$((undockGeneration + 1))
  undockGeneration="$scheduledSuspendGeneration"
  logger -t yuki-lid-state-watch \
    "dock disconnected while lid closed; scheduling suspend generation=$scheduledSuspendGeneration"
fi
```

Update state writes to track `dpCount`:

```bash
printf 'prevDpCount=%q\n' "$dpCount" >> "$stateFile"
```

### 2. Survive `nixos-rebuild switch`

The rebuild should not leave the graphical session orphaned from its services. Options:

- **Avoid restarting `user@1000.service`** during rebuild (if possible).
- **Re-activate `graphical-session.target`** after the user manager restarts (e.g., a Hyprland rule or session wrapper that re-announces the graphical session to systemd).
- **Move critical sleep services out of `graphical-session.target`** — `yuki-lid-state-watch` doesn't actually need Wayland; it only needs `busctl` and `hyprctl`. It could run as `WantedBy=default.target` instead.

### 3. `hypridle`: check AC power before hibernating

Wrap the command so it only fires on battery:

```ini
listener {
  on-timeout = bash -c '[[ "$(cat /sys/class/power_supply/ADP0/online)" == "0" ]] && systemctl suspend-then-hibernate'
  timeout = 900
}
```

Or use a helper script with additional checks (e.g., skip if docked):

```bash
#!/usr/bin/env bash
[[ "$(cat /sys/class/power_supply/ADP0/online)" == "1" ]] && exit 0
hyprctl monitors all | grep -q '^Monitor DP-' && exit 0
systemctl suspend-then-hibernate
```

### 4. Re-enable `logind` as a last-resort fallback

Consider setting `HandleLidSwitch=suspend-then-hibernate` (at least for the non-docked case) so that even when every user service is dead, closing the lid still does something. The custom scripts can still inhibit logind when they want finer-grained control.

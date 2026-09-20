# Desktop Architecture: Hyprland Shaped to Kamoi

## Model
Kamoi (~/code/sandbox/irori) tiles the web on Android: one page per window, a master pane and a stack, on an ordered strip of workspaces. Its README is the product manual.

Hyprland provides the required primitives that scrollable compositors lack:
- `swapwithmaster`
- `orientationcycle`
- `pin`
- `focuscurrentorlast`
- bounded capacity per workspace

## Lua Config Over `.conf`
Hyprland 0.56 deprecates `.conf` (scheduled for removal in 0.57). Cairn uses Lua (`~/.config/hypr/hyprland.lua`).
Under Lua, CLI dispatch forms change:
- `hyprctl keyword` is rejected in favor of `hyprctl eval 'hl.monitor({...})'`.
- `hyprctl dispatch layoutmsg "..."` becomes `hyprctl dispatch 'hl.dsp.layout("...")'`.
- `gaps_out` accepts integers or `{ top, right, bottom, left }` tables, rejecting comma-separated strings.

## Scale Ladder Math
Hyprland quantises display scale to 1/120 and requires integer logical pixels (`output/Monitor.cpp`):
A legal scale is `N/120` where `N` divides `120 * gcd(pw, ph)`.
On Samsung Galaxy Book3 Pro 360 (2880x1800), this yields 11 valid scale rungs between 1.0 and 2.0. `hypr-scale` calculates rungs dynamically from the active display mode.

## Session Target Lifecycle
Hyprland imports environment variables on startup but does not activate `graphical-session.target`.
`graphical-session.target` has `RefuseManualStart=yes`, so scripts cannot start it directly.
`start-mountainous` waits for `HYPRLAND_INSTANCE_SIGNATURE` to appear in the user systemd manager and starts `hyprland-session.target`, which binds to `graphical-session.target` and brings up user services (Quickshell).
On exit, `start-mountainous` stops `graphical-session.target` to cleanly tear down session services.

## Trackpad Ergonomics and Palm Rejection
The Zenbook A16 has a 149x97mm glass clickpad without physical pressure or touch-size sensors. Libinput cannot distinguish palms from fingertips by contact area or pressure, and its edge exclusion zones are capped at 8mm.

Accidental palm interference while typing is resolved through:
- `tap_to_click = false`: Software tap clicks are disabled; only physical mechanical clicks on the pad actuate clicks.
- `tap_and_drag = false`: Prevents accidental drag gestures from resting hands.
- `clickfinger_behavior = true`: Button presses anywhere map to LMB (1 finger), RMB (2 fingers), or MMB (3 fingers). Disables bottom corner software button zones.
- `disable_while_typing = true`: Paired with the Kanata virtual keyboard to suppress motion during typing bursts.
- Libinput quirk `ModelTouchpadPhantomClicks=1`: Disregards chassis flex click events when no touch is registered.


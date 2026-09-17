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

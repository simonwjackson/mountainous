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

## Title Bars: a Patched hyprbars
Under the Platinum desktop theme, windows get Mac OS 8 title bars from `hyprbars-platinum`: nixpkgs' `hyprlandPlugins.hyprbars` with `modules/hyprland/hyprbars-platinum.patch`. `modules/hyprland/titlebars.lua` loads and styles it; `docs/plans/desktop-themes.md` (Window title bars) has the details.
- **Why a patch.** Stock hyprbars draws round buttons on one side and a flat fill. No Hyprland release adds square boxes on both ends, stripes or a bevelled frame, so an upgrade would not remove the patch.
- **Why nixpkgs' Hyprland.** A plugin must be built against the exact Hyprland binary. nixpkgs ships Hyprland and hyprbars as a pair, so `nix flake update` moves both. An assertion in `modules/hyprland.nix` refuses any other `programs.hyprland.package`. A nixpkgs bump that breaks the patch fails the build, never the session; rebase the patch then. A mismatched plugin that loads anyway is refused by its own version check, with a notification.
- **Loading.** The NixOS module's plugin option writes hyprlang, which the Lua session never reads. `titlebars.lua` calls `hl.plugin.load()` on every config parse: after a parse Hyprland unloads any plugin the parse did not name, so a config that named it only on the first parse kept the nested test session from ever finishing start-up (`PluginSystem.cpp` `updateConfigPlugins` reads as a load and unload loop).
- **Which windows.** Hyprland answers "server-side" to every decoration request, so the plugin asks what the client requested. A client that requested client-side decorations, or never made a decoration object (GTK4/libadwaita, GTK3, a normal Chromium window), gets no bar. No hand-kept list of apps.

## Session Target Lifecycle
Hyprland imports environment variables on startup but does not activate `graphical-session.target`.
`graphical-session.target` has `RefuseManualStart=yes`, so scripts cannot start it directly.
`start-mountainous` waits for `HYPRLAND_INSTANCE_SIGNATURE` to appear in the user systemd manager and starts `hyprland-session.target`, which binds to `graphical-session.target` and brings up user services (Quickshell).
On exit, `start-mountainous` stops `graphical-session.target` to cleanly tear down session services.


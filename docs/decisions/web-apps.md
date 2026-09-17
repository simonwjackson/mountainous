# Web Applications in Chromium --app Mode

## Concept
Kamoi installs web pages as PWAs and lists them in the omni bar under "PWA apps". On the desktop, the equivalent is Chromium's `--app` mode, which renders pages without tab strips, address bars, or title bars so Hyprland tiles them as standard windows.

## Verified Runtime Behaviors (on Hiyori against Chromium 153)
- `--ozone-platform=wayland` must be explicitly specified. Neither `NIXOS_OZONE_WL` nor `--ozone-platform-hint=auto` was sufficient when sessions inherit older environments.
- Chromium logs `"'--ozone-platform=wayland' is not compatible with Vulkan"` and runs normally; this log is benign.
- `--class` is ignored on Wayland. Chromium derives `app_id` from the URL, producing `chrome-<host>__-Default`. Window rules and `startupWMClass` must use the host-derived class.
- All web apps share a single profile directory (`~/.local/share/mountainous/browser`) so authentication sessions (e.g., Google login) are shared rather than isolated per app.

## Single CDP Endpoint and Flag Inheritance
All web-app launches route through `web-app`:
1. Shared `--user-data-dir`: Secondary `--app` launches join the existing browser process and share a single Chrome DevTools Protocol (CDP) endpoint.
2. `--remote-debugging-port=0`: Chromium selects a random loopback port and writes it to `<profile>/DevToolsActivePort`.
3. The flag must be present on every launch command so the initial instance binds the debugging port regardless of which app was opened first.

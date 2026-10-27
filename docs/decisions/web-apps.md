# Web Applications in Chromium --app Mode

## Concept
Kamoi installs web pages as PWAs and lists them in the omni bar under "PWA apps". On the desktop, the equivalent is Chromium's `--app` mode, which renders pages without tab strips, address bars, or title bars so Hyprland tiles them as standard windows.

## Verified Runtime Behaviors (on Hiyori against Chromium 153)
- `--ozone-platform=wayland` must be explicitly specified. Neither `NIXOS_OZONE_WL` nor `--ozone-platform-hint=auto` was sufficient when sessions inherit older environments.
- Chromium logs `"'--ozone-platform=wayland' is not compatible with Vulkan"` and runs normally; this log is benign.
- `--class` is ignored on Wayland. Chromium derives `app_id` from the URL, producing `chrome-<host>__-Default`. Window rules and `startupWMClass` must use the host-derived class.
- All web apps share a single profile directory (`~/.local/share/mountainous/browser`) so authentication sessions (e.g., Google login) are shared rather than isolated per app.

## A Declared App Is Not an Installed PWA
The two launch paths draw different window frames. This is the reason a PWA
installed through Chromium shows a title bar and the declared web apps do not.

| Launch | Window | Frame |
|---|---|---|
| `chromium --app=<url>` (`web-app`) | generic app window | none |
| `chromium --app-id=<id>` (Chromium Install button) | installed web app | Chromium client-side title bar, origin text, menu, minimise, maximise, close |

Measured against Chromium 153 under Hyprland 0.56.2:

- `--app=https://example.com` rendered with no frame. Content filled the window.
- `--app-id=<id>` rendered a title bar showing the origin
  `forgerie.hummingbird-lake.ts.net` and the app menu and window buttons.
- `--disable-features=WebAppFrameToolbarView` changed nothing. The feature name
  does not exist.

### Why the frame cannot be removed
Chromium's `AppBrowserController::ShouldUseCustomFrame()` returns `true`. An
installed web app is the only case that builds that controller, so Chromium
always draws its own frame for `--app-id` windows and ignores the compositor.
With `--app` Chromium draws no frame and asks the compositor for server-side
decorations. Hyprland draws no title bar of its own, so under most desktop
themes the window is frameless. Under Platinum the hyprbars-platinum plugin
draws a Mac OS 8 title bar on it (`docs/decisions/hyprland.md`); an
`--app-id` window keeps Chromium's frame and gets none.

Upstream keeps this behaviour on purpose, to show a tamper-proof origin in the
title bar. Chromium closed the request to change it as infeasible. There is no
command-line flag and no user preference that removes it. The `Borderless`
display mode exists, but it applies to Isolated Web Apps only, not to ordinary
installed PWAs.

### The rule
Declare each web app in `modules/web-apps.nix`. Do not install the same site as
a PWA through Chromium. A Chromium-installed PWA is also invisible to the CDP
spine, because it runs in the default Chromium profile, not in the shared
`mountainous/browser` profile that `CdpBrowser.qml` reads.

If a PWA was installed by mistake, remove its launcher:

```
rm ~/.local/share/applications/chrome-<app-id>-Default.desktop
```

The site's cookies and storage in the default profile stay. Chromium offers the
Install button again on the next visit, so the removal is repeatable.

## Single CDP Endpoint and Flag Inheritance
All web-app launches route through `web-app`:
1. Shared `--user-data-dir`: Secondary `--app` launches join the existing browser process and share a single Chrome DevTools Protocol (CDP) endpoint.
2. `--remote-debugging-port=0`: Chromium selects a random loopback port and writes it to `<profile>/DevToolsActivePort`.
3. The flag must be present on every launch command so the initial instance binds the debugging port regardless of which app was opened first.

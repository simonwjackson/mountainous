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
decorations. Our patched hyprbars draws the caption and outer frame under
**both Platinum and Windows 98** (`docs/decisions/hyprland.md`). An `--app-id`
window keeps Chromium's frame and gets no compositor caption. Normal browser
windows can also ask for our frame while keeping Chromium's tabs and toolbar;
see Phase A below.

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

## Normal browser windows: Phase A (2026-10-27)

Myoko selects the `desktop` layer in `modules/hosts/myoko.nix`.
`modules/web-apps.nix` installs **Chromium**, not Google Chrome. The locked
nixpkgs package is **153.0.8010.52**. `modules/browser.nix` delivers
`CdpBrowser.qml` through Hjem at `.config/quickshell/mountainous/CdpBrowser.qml`.
The desktop's `modules/hyprland.nix` also delivers `.config/hypr/hyprland.lua`
and `titlebars.lua` through Hjem. Hjem does not own Chromium's mutable
Preferences. Myoko's other layers are `disk`, `galaxy-book3` and
`session-restore`; the migration must precede the last one's app launches.
Ordinary `chromium` uses `$XDG_CONFIG_HOME/chromium` (normally `~/.config/chromium`);
`web-app` uses `~/.local/share/mountainous/browser`. They remain separate.

`modules/chromium-frame.nix` uses the upstream NixOS Chromium module:

- `programs.chromium.initialPrefs.browser.custom_chrome_frame = false` seeds
  the first Default profile in a new user-data root through
  `/etc/chromium/initial_preferences`. The locked
  nixpkgs revision is `4975466d324710c576dc11ad614684e6bd8cad8e`; its
  [Chromium patch](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/pkgs/applications/networking/browsers/chromium/patches/chromium-initial-prefs.patch)
  selects this path, and its [NixOS module](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/nixos/modules/programs/chromium.nix)
  writes it.
- `extensions.theme.system_theme = 1` selects GTK for that first-run profile. It does not
  install a browser extension. Existing theme choices are not overwritten.
- The `chromium-frame` user oneshot migrates existing profiles in both known
  user-data roots. `start-mountainous` waits for it **before** starting
  Hyprland, session restore or the shell. It changes only
  `browser.custom_chrome_frame`, preserves other keys and permissions, writes
  atomically, keeps `Preferences.before-mountainous-frame` once, and logs changes.
- `SingletonLock` is a dangling `<hostname>-<pid>` symlink. A same-host lock
  defers the root only while that PID exists with `chromium` in its Linux
  `/proc/<pid>/comm` name. A dead PID or one reused by another program is stale
  and does not block migration. Foreign-host, malformed or unreadable locks
  still defer the root. The service never deletes or changes the lock;
  Chromium cleans up stale locks itself. Invalid JSON or symlinked Preferences
  fail without overwriting the file. Errors go to the user journal; they do
  not prevent desktop login.

This is a first-run default plus an offline login migration, **not** a managed
policy or a live writer. Do not run it alongside a manually launched Chromium:
Chromium does not share our file transaction lock. Login ordering prevents the
normal desktop-start race; any browser already running is skipped. Such a
profile keeps its old frame for this session. A later login after Chromium
exits applies the migration; a browser restart alone does not rerun the service.
After closing Chromium, `systemctl --user start chromium-frame.service` can
apply the migration without logging out. Custom `--user-data-dir` roots are not scanned. `--no-first-run` can bypass the
initial-preferences seed; existing roots and newly added profiles are handled
by the next stopped-profile login preflight.

### Why this preference, not a flag or a policy

Pinned Chromium sources (153.0.8010.52):

1. [`pref_names.h`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/common/pref_names.h)
   names `browser.custom_chrome_frame` and `extensions.theme.system_theme`.
2. [`BrowserNativeWidgetAuraLinux::UseCustomFrame`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/ui/views/frame/browser_native_widget_aura_linux.cc)
   respects the frame preference for normal windows when the platform supports
   SSD. Web apps and picture-in-picture are separate cases. The same file's
   `OnUseCustomChromeFrameChanged` updates the frame hints in process.
3. [`configuration_policy_handler_list_factory.cc`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/policy/configuration_policy_handler_list_factory.cc)
   has no policy mapping for that frame preference. The
   [`Chrome switch definitions`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/common/chrome_switches.cc)
   provide no equivalent frame switch. An arbitrary policy key is not a way to
   set arbitrary Preferences. `WaylandWindowDecorations` is not the control.
4. Chromium's [other preferences guide](https://www.chromium.org/administrators/configuring-other-preferences/)
   explains that initial preferences are copied on first run, not enforced on
   an existing profile. [`first_run.cc`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/first_run/first_run.cc)
   implements that copy and the first-run sentinel.
5. [`SystemTheme`](https://github.com/chromium/chromium/blob/153.0.8010.52/ui/color/system_theme.h)
   fixes GTK at value 1. [`linux_ui_factory.cc`](https://github.com/chromium/chromium/blob/153.0.8010.52/ui/linux/linux_ui_factory.cc)
   otherwise falls back to the default theme for an unrecognised desktop such
   as Hyprland. [`appearance_handler.cc`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/ui/webui/settings/appearance_handler.cc)
   implements the settings page's `useGtkTheme` action.

6. [`ThemeServiceAuraLinux`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/themes/theme_service_aura_linux.cc)
   selects the native GTK supplier from `system_theme`. [`gtk_ui.cc`](https://github.com/chromium/chromium/blob/153.0.8010.52/ui/gtk/gtk_ui.cc)
   reads native colours and font settings; it does not supply GTK tab widgets.
   NixOS's [Wayland session module](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/nixos/modules/programs/wayland/wayland-session.nix)
   enables dconf; its [dconf module](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/nixos/modules/programs/dconf.nix)
   supplies `GIO_EXTRA_MODULES`. A private test bus needs both the service file
   and that backend to reproduce the real desktop.

The GTK strip's five palettes follow `desktop-theme` live. Font glyphs can keep
the startup family until restart, and the tabs/toolbar retain Chromium geometry.
Existing profiles must choose **Use GTK** once; the migration preserves their
current theme choice. No generated Chromium theme extension ships.

A private CDP false → true → false frame-pref roundtrip exposed a live-update
limit: false removed Chromium's close button, but the window did not request SSD
again and our caption stayed absent. Startup with false did request SSD and
worked under both themes. Do not use the source's live observer as proof that
all Wayland transitions work. This phase uses stopped-profile migration and
restart, not CDP preference writes.

The cost is one small, bounded migration because upstream exposes no frame
policy. This does not turn Chromium's tab strip into our own widgets. The
phases, alternatives, screenshots and measured limits are in
[`desktop-themes.md`](../plans/desktop-themes.md#chromium-outer-chrome-phase-a-and-next-phases).

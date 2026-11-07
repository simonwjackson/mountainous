# Web Applications in Chromium --app Mode

## Concept
Kamoi installs web pages as PWAs and lists them in the omni bar under "PWA apps". On the desktop, the equivalent is Chromium's `--app` mode, which renders pages without tab strips, address bars, or title bars so Hyprland tiles them as standard windows.

## Verified Runtime Behaviors (on Hiyori against Chromium 153)
- `--ozone-platform=wayland` must be explicitly specified. Neither `NIXOS_OZONE_WL` nor `--ozone-platform-hint=auto` was sufficient when sessions inherit older environments.
- Chromium logs `"'--ozone-platform=wayland' is not compatible with Vulkan"` and runs normally; this log is benign.
- `--class` is ignored on Wayland. Chromium derives `app_id` from the URL, producing `chrome-<host>__-Default`. Window rules and `startupWMClass` must use the host-derived class.
- All web apps share a single profile directory (`~/.local/share/mountainous/browser`) so authentication sessions (e.g., Google login) are shared rather than isolated per app.

## Keep Installed PWAs, Replace Their Frame

A declared app and an installed PWA are different browser objects. Keep both
launch paths; do not rewrite an installed app to a generic URL launch.

| Launch | Browser object | Frame without our fullscreen rule |
|---|---|---|
| `chromium --app=<url>` (`web-app`) | generic app window | asks for our server-side caption |
| `chromium --app-id=<id>` (Chromium Install button) | installed web app | Chromium client-side title bar, origin text, menu and window buttons |

Chromium 153's `AppBrowserController::ShouldUseCustomFrame()` requests its own
frame for installed apps. The frame preference used for normal windows does
not override it. `--disable-features=WebAppFrameToolbarView` changed nothing;
that feature name does not exist. `Borderless` applies to Isolated Web Apps,
not ordinary installed PWAs.

### Client-only fullscreen (2026-11-04)

`hyprland.lua` matches `^(chromium-browser|chromium|chrome-.*)$`, including
installed classes such as `chrome-<id>-Default`. Its `fullscreen_state = "0 2"`
keeps the window tiled inside Hyprland but tells Chromium it is fullscreen.
Chromium then hides its tab strip, toolbar and installed-app title bar.
`suppress_event = "fullscreen"` prevents client requests from changing that
split. Our hyprbars patch treats a client-only fullscreen window as drawing
no frame, even if it requested client-side decorations. Platinum light/dark
and Memphis supply the caption and outer frame instead.

Installed PWAs stay installed in their original profile. They keep periodic
background sync, persistent storage grants, remembered File System Access,
protocol/file handlers, badging, and manifest scope. No launcher, cookie or
profile conversion is needed. New declared apps still live in
`modules/web-apps.nix` and use the shared web-app root.

**Super+U** shows or hides Chromium's own UI on the active Chromium window.
Use it to recover the address bar and menu, including the Install app action,
then press it again to return to the page-only window. Other clients do not
change. `mountainous.browser.kiosk.enable` adds `--kiosk` to the wrapper to
remove the “press and hold Esc” fullscreen bubble. It is off by default.
Chromium's `--kiosk` blocks DevTools (F12, Ctrl+Shift+I, Inspect) and the
page right-click menu, and daily browsing needs both. With it off, the Esc
bubble shows when a page window enters page-only mode. **Cost when on: F11
does nothing, and no DevTools or right-click menu.** Restart Chromium after
changing the wrapper option. Super+U is the recovery control, not F11.

This deliberately hides Chromium's native origin/security display. A page's
title and our caption are not trusted origin indicators. Super+U recovers the
browser UI; no replacement security display ships. Kiosk with daily profiles,
downloads, permission prompts, printing and extension popups still needs
post-deployment checks. The standalone plugin probe proved captions on a
client-decorated Chromium window; a real installed PWA with the new plugin
still needs a post-deployment check on Myoko.

### Rollback and navigation

Set `mountainous.browser.kiosk.enable = false` to remove only the kiosk flag.
Set `CHROMIUM_FAKE_FULLSCREEN = false` at the top of the Chromium page-frame
section in `hyprland.lua` to disable the rule and Super+U. Reload Hyprland and
restart Chromium to return to ordinary browser UI. The stopped-profile frame
preference below remains useful then; installed PWAs return to Chromium's
frame. No app needs uninstalling.

`CdpBrowser.qml` can navigate a uniquely identifiable installed PWA through its
original profile's endpoint. The shared `mountainous/browser` root and normal
Chromium root remain separate. The rejected popup conversion, memory limits
and navigation details are recorded in
[`chromium-windows.md`](../plans/desktop-themes/chromium-windows.md).

## Single CDP Endpoint and Flag Inheritance
All web-app launches route through `web-app`:
1. Shared `--user-data-dir`: Secondary `--app` launches join the existing browser process and share a single Chrome DevTools Protocol (CDP) endpoint.
2. `--remote-debugging-port=0`: Chromium selects a random loopback port and writes it to `<profile>/DevToolsActivePort`.
3. The flag must be present on every launch command so the initial instance binds the debugging port regardless of which app was opened first.
4. `--disable-blink-features=AutomationControlled`: the debugging port alone makes Chromium report `navigator.webdriver = true` to every page. Bot checks read that as automation and challenge or block the user. This flag keeps CDP and reports `false`, so sites cannot see that the browser accepts automation.

## Normal browser system-frame preference: Phase A (2026-10-27)

This preference remains the fallback when client-only fullscreen is off or
Super+U shows the browser UI. It is not required to force our caption in
client-only fullscreen; the plugin override handles that state directly.

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

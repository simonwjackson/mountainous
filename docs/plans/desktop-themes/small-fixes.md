# Small fixes after Myoko generation 57

Status: built on its own branch from `cairn`, not deployed. Written 2026-10-28.
Two fixes for both desktop themes. The parent lands and deploys.

## `ThemeSounds is not defined` on a reload

**Cause.** Hjem links a new generation file by file. The running Quickshell
reloads at once when a watched file changes (Quickshell 0.3.1 has no
debounce). On Myoko the outgoing process reloaded with the new `shell.qml`
before Hjem had linked the new `ThemeSounds.qml`. Quickshell's scan then had
no `ThemeSounds` type, and `shell.qml`'s binding
`soundEffectsActive: ThemeSounds.active` logged
`ReferenceError: ThemeSounds is not defined`. `quickshell-after-hjem` then
restarted Quickshell on the complete tree, which is why the new processes
were clean. Teardown is not involved: Quickshell deletes the root before the
engine and stops all JavaScript before it destroys singletons.

**Fix.** `shell.qml` is the only reader of `ThemeSounds`. It now reads it only
when the type exists:
`typeof ThemeSounds !== "undefined" && ThemeSounds.active`. Sounds are off for
the few milliseconds of a half-linked generation. Only a missing type is
tolerated; an error inside `ThemeSounds` still surfaces.
`checks.bar-delivery` now requires `ThemeSounds.qml` and `SoundEvents.qml` in
every generation, so a missing file cannot ship. The `SoundEvents.requested`
callers run on user events or on object creation, and `SoundEvents` already
exists in the deployed tree, so they need no guard.

**Test.** `theme-dev/reload.test.js`, in `checks.desktop-theme-shell`, replays
the deploy with production's own `soundEffectsActive` line: a tree without
`ThemeSounds.qml`, then the new `shell.qml` alone (Quickshell reloads the half
tree), then `ThemeSounds.qml` and a restart. Any QML warning fails. Before the
fix it failed with the Myoko message
(`WARN scene: @shell.qml[7:-1]: ReferenceError: ThemeSounds is not defined`,
log `/tmp/tandem/small-fixes/logs/reload-red-before-fix.log`).

## Phase 4 art: Chromium and web apps on the taskbar and strip

**Cause.** Win98's `start-model.js` `appIcon` mapped every id or name that
contained "chrom" to the Win98 set's own `chromium` SVG, which is Chromium's
logo. That covered Chromium, every `--app` web app and every PWA, on the
taskbar, the window menus, Cool Switch and the Find window. Platinum asked the
desktop entry: a PWA's entry, written by Chromium, names the site's own PNG by
path, so PWAs bypassed the theme.

**Fix: one shared place, `app-icon.js`.**

| Window class | Icon-theme name | Platinum | Win98 |
|---|---|---|---|
| `chromium-browser`, `chromium` | `chromium` | Globe cube | Chicago95's browser (Internet Explorer) |
| `chrome-<host>__-Default` (`--app`) | the entry's `webapp-<id>`, else the class | Lettermark cube | Lettermark tile |
| `chrome-<app id>-Default` (installed PWA) | the class | Lettermark cube | Lettermark tile |
| Unknown site or PWA | the class, falling back to `chromium` | Globe, or the PWA's own hicolor icon | IE, or the PWA's own icon |

- Platinum: `PlatinumDesktop.appIcon` (Control Strip, its menus, Find, Go to
  Address), `PlatinumTopBar`, `PlatinumAppIcon` and `PlatinumFindMenu` (app
  and recent rows) use it.
- Win98: `start-model.js` `appIcon` returns `theme:<name>` for these classes,
  and `Win98Icon` draws a `theme:` name from the icon theme at 16 u (32 px at
  1.5, a Chicago95 size). So the taskbar buttons, the drag ghost, the window
  lists in Start and the button menus, Cool Switch and the Find window all
  follow. The icon-theme fallbacks in `Win98Taskbar`, `Win98CoolSwitch` and
  `Win98FindWindow` use it too.
- Art: `modules/web-app-pwas.json` lists the eight installed PWAs (app id,
  name, letter, tint). `generate-desktop-art.py` draws a `webapp-<id>`
  lettermark for each in both themes. It also links every web app's window
  class to its lettermark: `chrome-<host>__-Default` for `web-apps.json`, and
  `chrome-<app id>-Default` for the PWAs.

| PWA | App id | Letter | Tint |
|---|---|---|---|
| Assistant | `ahmfndipfijlijminhiobipfjpafbndb` | A | `#3b5bdb` |
| Caliper | `ephhkmeofmgblgjpkjnfjjlbojfjlcah` | C | `#0b7a75` |
| Household groceries | `gehcogodmjijngibdplkjhkdjpkccahb` | G | `#2f8f3a` |
| Pyxis | `ghklfalheoohfhobcjmoijclhibhcehj` | P | `#7048e8` |
| append | `kgbpjefoeahnljaodhdhocnlefgggebf` | a | `#c2410c` |
| Jellyfin | `lneafpomhdmfgkblnkjeglpppndalpik` | J | `#0089c2` |
| Microsoft Teams | `ompifgpmddkgmclendfeacglnodjjndh` | T | `#4b53bc` |
| Pace Goal Tracker | `pbdginngdcogphkbiafcmdmgkbfpmoah` | P | `#d6336c` |

**Tests.**

- `app-icon.test.js` (in `checks.platinum-desktop` and `checks.app-icons`):
  the class rules, that every listed web app's class is recognised, and that
  every lookup site imports `app-icon.js`.
- `themes/win98/models.test.js`: `theme:` names.
- `tests/desktop-art.py` (`checks.native-themes`): in both themes every
  lettermark and its window class resolve to the same file outside hicolor,
  and no two lettermarks are equal.
- `checks.app-icons` (new): the real Win98 taskbar and Platinum Control Strip
  with the patched Quickshell and the art package. The fixture windows are
  Chromium by both classes, Reddit, Jellyfin, Teams, an unknown site and
  Ghostty. hicolor holds stand-ins for Chromium's logo and a PWA's own icon.
  The check fails if any of their colours shows, or if a lettermark's tint is
  missing. Its output is the crops.

**Evidence:** `/tmp/tandem/small-fixes/` (`win98-taskbar.png`,
`platinum-strip.png`, the full shots).

**Not covered.** Win98 still draws its own set for Ghostty, Signal, Zed, OBS
and Firefox (`term`, `signal`, …). Those are the Win98 mock's icons, not
Chromium's logo, but they are not Chicago95's art either. Recent Applications
entries recorded before this change keep the icon they were recorded with. A
web app opened in a profile other than `Default` is not recognised.

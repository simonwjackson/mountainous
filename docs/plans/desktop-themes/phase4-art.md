# Phase 4, part 1: icons, cursors and the desktop pattern (both themes)

Status: built on `cairn`, not deployed. Written 2026-10-28. Menu sounds and the boot screen are part 2 (another worker).

`desktop-theme` now switches the freedesktop icon theme and the cursor theme with the desktop theme, and Quickshell draws a desktop pattern per appearance under every window. All five appearances get all three.

| Appearance | Icon theme | Cursor theme | Desktop pattern |
|---|---|---|---|
| Platinum light | `Mountainous-platinum` | `Mountainous-platinum-cursors` | Lattice, periwinkle `#7c80c4` / `#6e72b6` |
| Platinum dark grey | same | same | Lattice, slate `#303138` / `#27282e` |
| Platinum Extra dark | same | same | Lattice, black `#000000` / `#0c0c10` (OLED) |
| Win98 light (Windows Standard) | `Mountainous-win98` | `Mountainous-win98-cursors` | Plain teal `#008080` |
| Win98 dark grey | same | same | Plain teal-grey `#1e2a2a` |

## What was built

| Part | Files |
|---|---|
| The art package: two icon themes, Chicago95's icon theme, two cursor themes (XCursor and hyprcursor in one directory each), licences, a manifest | `scripts/generate-desktop-art.py`, `lib/desktop-art.nix`, `modules/desktop-art.nix` (installs it; `xdg.icons.fallbackCursorThemes` sends "default" to the alias below) |
| The registry names them, and the pattern tiles | `modules/quickshell/themes.json` `art`: `icons`, `cursors`, `cursorSize`, `patternCell`, `patterns.{light,dark,extra}`; `theme-dev/check-boundaries.py` validates it |
| `desktop-theme` applies them | `modules/theme.nix` (dconf `icon-theme`, `cursor-theme`, `cursor-size`; `hyprctl setcursor` on every change, beside the title-bar hook), `scripts/apply-native-theme.py` (GTK 3/4 `settings.ini` icon and cursor keys, qt5ct/qt6ct `icon_theme`, `~/.icons/Mountainous-cursors/index.theme`) |
| Hyprland at login | `modules/hyprland/hyprland.lua`: `XCURSOR_THEME=Mountainous-cursors` (the alias), `HYPRCURSOR_THEME` read back from the alias, size 24; `cursor.sync_gsettings_theme = false` (desktop-theme owns the GNOME key) |
| The bars' icons follow live | `lib/quickshell.nix` + `lib/patches/quickshell-icon-theme.patch` (Quickshell 0.3.1): a writable `Quickshell.iconTheme`, and every `iconPath()` URL names the theme; `Theme.qml` sets it from `art.icons` before it changes `Theme.name`; `bars.nix` runs this Quickshell |
| The desktop pattern | `DesktopPattern.qml` (one background-layer surface per screen, from `shell.qml`), `desktop-art.js` (which tile, and the tile size on whole device pixels), `themes/platinum/patterns/{light,dark,extra}.svg`, `themes/win98/patterns/{light,dark}.svg` |
| Web-app lettermarks per theme | `modules/web-apps.json` (the list moved out of `web-apps.nix` so the art generator can read it) |
| Checks | `checks.native-themes` grows: after every `apply`, `set`, `toggle`, `reapply` and `extra toggle` in `scripts/test-native-themes` (29 states) it asserts the icon and cursor names in dconf, GTK 3/4, qt5ct/qt6ct and the alias, the recorded `hyprctl setcursor <theme> 24`, and the pattern file that `desktop-art.js` picks from the state files. `tests/desktop-art.py` checks the package; `desktop-art.test.js` the pattern policy |

### Icons

**Platinum: Chi-Nata, not NineIcons.** NineIcons (grassmunk, in `grassmunk/Platinum9`) has no licence, and the same repository redistributes Apple's Charcoal and Monaco fonts. MoNine (a NineIcons derivative) has no licence either. Retrosmart icons are Haiku-based, not Mac. Chi-Nata (DawnVespero) is CC BY-SA 4.0 and the only licensed Mac OS 9 set found. It is small: 66 usable 32 px icons and 63 at 256 px (some upstream files are macOS alias records, one "256" file is 32 px; the generator skips any file that is not a PNG of its directory's size). Its own `index.theme` is broken (wrong directory names, lower-case keys), so the generator writes a correct one.

Chi-Nata has no icon for any of Myoko's apps. The generator draws original 32 px "cubes" in Chi-Nata's style (1 px black outline, an upright front face, oblique top and side, a soft shadow): terminal (Ghostty), globe (Chromium), page and pencil (Zed), speech bubble (Signal), lens (OBS), crystal (Obsidian), a diamond for the generic application, and a lettermark cube per web app in the app's tint with its letter in ChicagoFLF. Every name these apps use is linked to its cube (`com.mitchellh.ghostty`, `chromium`, `zed`, `dev.zed.Zed`, `signal-desktop`, `org.signal.Signal`, `com.obsproject.Studio`, `obsidian`, `md.obsidian.Obsidian`, `webapp-*`, `application-x-executable`, …).

**Win98: Chicago95.** Its icon theme is copied into the package without its `scalable` and `symbolic` directories: between PNG sizes Qt and GTK would otherwise draw the SVG tracings, resampled. Copying (17 MiB package) instead of linking keeps the 83 MiB Chicago95 source (sounds, Plymouth, KDE, screenshots) out of the closure. `Mountainous-win98` inherits Chicago95 and adds what it lacks: Ghostty → `utilities-terminal` (MS-DOS Prompt), Zed → `accessories-text-editor` (Notepad), Signal → `empathy` (the messenger flower), OBS → `kazam` (projector), Obsidian → `tomboy` (note). Chromium uses Chicago95's own `chromium` (Internet Explorer). Web apps get raised Win98 tiles in the tint with the letter in W95FA Grid, struck twice, at 16 and 32 px.

**Fallbacks.** Platinum inherits `Adwaita,hicolor`; Win98 inherits `Chicago95,hicolor`. `tests/desktop-art.py` resolves Myoko's apps, the web apps, `folder`, `text-x-generic` and `application-x-executable` through those chains and fails if any lands on hicolor. An app that is not on that list still shows its own hicolor icon: the theme cannot know the name in advance.

### Cursors

| | Platinum | Win98 |
|---|---|---|
| Source | Retrosmart X11 cursors, bitmap set, black fill and white outline (the Mac OS arrow), monochrome | Chicago95 Standard Cursors (static hourglass, as Win98's default) |
| 1x art | 32 px canvas | 32 px canvas |

Each shape is written once per cursor-shape-v1 name, with every legacy X11 name and hash as an alias (`ROLES` in the generator). Scaling is by whole factors with nearest neighbour only.

- **hyprcursor (what Hyprland draws):** images of 32, 64, 96 and 128 px (1x to 4x), `resize_algorithm = nearest`, `nominal_size = 0.5625`. Hyprland asks for `size × scale` = 24 × 1.5 = 36 and draws the image 1:1 on device pixels; `round(36 / 0.5625)` = 64, the 2x image. **At scale 1.5 one art pixel is 2 device pixels** (Retrosmart's arrow is 17 art px = 34 device px, about 4 mm on Myoko's 215 ppi panel; Chicago95's is 19 = 38). That is the Win98 theme's own unit (1 u = 2 device px). Scales 2.25 and 3 are exact too (3x, 4x).
- **XCursor (clients that draw their own pointer):** nominal 24 → 1x, 36 → 2x, 48 → 2x, 72 → 3x.

Live switching: `desktop-theme` runs `hyprctl --instance 0 setcursor <theme> 24`, writes the GNOME `cursor-theme`/`cursor-size` keys, GTK's `gtk-cursor-theme-*`, and `~/.icons/Mountainous-cursors/index.theme` (`Inherits=<theme>`). GTK 4, Qt 6 and Chromium ask the compositor for a cursor shape, so Hyprland's switch reaches them at once. GTK 3 reloads from the GNOME key. A client that loads XCursor files itself reads `XCURSOR_THEME=Mountainous-cursors`, a stable name, so even a process whose environment predates the switch gets the current cursors the next time it loads them.

### Desktop pattern

A Quickshell `WlrLayer.Background` surface per screen (`mountainous-desktop`), shared rather than inside a Desktop: a theme swap repaints it in place, so there is never a second full-screen surface or a black frame, and the existing layer-surface assertions of `switch.sh` still hold. It reserves nothing and its input mask is empty. It sits under every window, under the bars and under the glance space (a Top-layer surface).

A tile is an 8 × 8 SVG. `desktop-art.js` `tile(base, dpr)` grows the cell to the first size whose tile is whole in logical pixels: at 1.5 the Platinum cell is 3 device px (the glance dither's cell, one 72-dpi Mac pixel) and the tile 16 logical px. The image is tiled from the screen's origin, unfiltered, so the pattern and the glance checker share one grid. hyprpaper was not used: it is another daemon, it would need its own IPC and its own state reader, and it cannot follow `Theme` live without one.

- **Platinum:** an original lattice (a diagonal crosshatch, 14 of 64 cells), low contrast so the glance's black checker still reads as an even 50 % over it. Extra dark stays black with the lattice at `#0c0c10`.
- **Win98:** plain colour, as Windows 98 shipped: teal in Windows Standard; in dark grey a teal-grey `#1e2a2a`, darker than the `#3c3c3c` face so windows and the taskbar stand off it, and dark enough that the Shut Down / glance checker (black) still reads.

## Live switching and restarts

| Surface | Icons | Cursor | Pattern |
|---|---|---|---|
| Quickshell bars, menus, Find, Start | Live: the new Desktop is built after `Quickshell.iconTheme` changes, and its URLs are new | Compositor | Live (same surface, new tile) |
| Shared surfaces that outlive a swap (omni card, notification popups) | On their next icon request | Compositor | — |
| Hyprland | — | Live (`setcursor`) | — |
| GTK 3 (file chooser portal) | Live (GNOME `icon-theme` key through dconf) | Live (GNOME `cursor-theme` key) | — |
| GTK 4 / libadwaita (Ghostty) | Live (GNOME key) | Compositor | — |
| Qt 6 / Qt 5 (OBS) | qt6ct/qt5ct reread their file 3 s after a change and reload the icon theme; app-owned icons (OBS's bundled ones) stay | Compositor | — |
| Chromium | Its own UI icons are Chromium's; the GTK file chooser follows | Compositor | — |

**Needs a restart or login:** the first deployment. Quickshell restarts with the patched binary through the existing Hjem hook. Hyprland reads `XCURSOR_THEME`/`HYPRCURSOR_THEME` and `sync_gsettings_theme` at login; until then the session's own cursor env stays `Adwaita`, but `desktop-theme` already switches Hyprland's cursor with `setcursor`. Apps started before the first deployment keep `XCURSOR_THEME=Adwaita` in their environment until restarted (only clients that load XCursor files themselves notice).

## Decisions made without asking

| Decision | Reason and cost |
|---|---|
| Patch Quickshell (`Quickshell.iconTheme`) instead of restarting it or leaving the bars' icons behind | Upstream 0.3.1 sets the icon theme only at launch (`//@ pragma IconTheme`, `QS_ICON_THEME`), and Qt's pixmap cache is keyed by URL, so the same `image://icon/chromium` would return the old theme's icon. The Win98 taskbar (owned by another worker) calls `Quickshell.iconPath()` directly, so a QML-only fix could not reach it. Cost: a 30-line patch to carry on every Quickshell update, and Myoko builds Quickshell instead of taking it from the cache. Checks and harnesses that run plain `pkgs.quickshell` still work: `Theme.qml` writes the property only when it exists |
| Chi-Nata over NineIcons | NineIcons has no licence. Cost: Chi-Nata is small; most of Platinum's icons are the originals drawn here or Adwaita's |
| Original cubes for Myoko's apps, not Chi-Nata look-alikes (Brave's lion for a browser, the envelope for chat) | A wrong metaphor is worse than a plain one. Cost: they are simpler than Chi-Nata's hand-drawn icons; a design review should judge them |
| Win98 substitutes from Chicago95 (Notepad for Zed, the messenger flower for Signal, the projector for OBS, a note for Obsidian) | Same reason; everything stays in the 98 idiom |
| 2 device pixels per cursor pixel at 1.5 | Whole pixels at Myoko's only scale and the size of a Win98 unit. 3 (the "72 dpi" size) made a 51 px arrow. Cost: at scale 1 or 2 hyprcursor resamples the nearest image with nearest neighbour, so some art pixels are uneven there |
| A shared background surface in `shell.qml`, not one per Desktop | One surface that never remaps; no layer-count changes for the switch tests. Cost: the pattern is chosen from the registry, not drawn by theme QML |
| `~/.icons/Mountainous-cursors` alias | NixOS's `XCURSOR_PATH` starts with `~/.icons`; an alias makes the environment stable across switches. Cost: one more generated file under the user's home |
| Web-app list moved to `modules/web-apps.json` | The generator reads it; `web-apps.nix` reads the same file. No behaviour change |

## Sources and licences

All three are non-flake inputs; no upstream art is in this repository. The package carries `share/licenses/desktop-art/` (Chi-Nata `LICENSE`, Retrosmart `LICENSE`, Chicago95 `README.md` and a `NOTICE`).

| Input | Locked revision | Licence evidence | Used for |
|---|---|---|---|
| `chi-nata-src` = `DawnVespero/Chi-Nata` | `8c5e6e647dbd47910f3c8b2a4ac27c4c65134b80` (2024-05-20) | `LICENSE`: CC BY-SA 4.0. README: "may use some of the original MacOS ico's as a base" | Platinum icons, copied unchanged into the store |
| `retrosmart-cursors-src` = `mdomlop/retrosmart-x11-cursors` | `768e207ce072945a7eba9caddc71f235b2036281` (2026-09-14) | `LICENSE`/`COPYING`: GPL-3.0 | Platinum cursors, recoloured by its own makefile rule (black fill, white outline), scaled |
| `chicago95-src` = `grassmunk/Chicago95` (existing) | `5da19b8b1e2a886ebf6628403023d5fac3acc3ee` | README: GPL-3.0+/MIT | Win98 icons (copied) and cursors (scaled) |
| Not used | | | NineIcons (`grassmunk/Platinum9`, no licence), MoNine (no licence), classic-mac-cursors (no licence) |

The originals (cubes, lettermarks, patterns) are this repository's own work. No artwork-rights review beyond the upstream licence files was done.

## Evidence

See "Evidence" below the sheets: `/tmp/tandem/phase4-art/` (http://100.114.19.92:8765/tandem/phase4-art/).

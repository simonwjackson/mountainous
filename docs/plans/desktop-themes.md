# Desktop themes for Myoko

Status: phase 1 implemented on the a05c2ead base; phase 2 (Windows 98) implemented on b7f20f04; phase 3 (Platinum Apple menu, Application menu and Control Strip) implemented on 37c91c12. The quiet-glyphs top bar (direction A) implemented on f47035fc. Written 2026-10-23. No deployment.

Base: `cairn` at `a05c2ead` ("dark grey Platinum bar and an Extra dark toggle"). The later `77dd2791` bevel/shadow change is not included; that line has not landed on `cairn`.

Later (2026-10-24): the `77dd2791` bevel and cast shadow were ported onto the phase 2 layout. `PlatinumTopBar` draws the bevel hairs, `PlatinumTokens` holds `barRaised`, `barBevelLight`/`barBevelDark` and `barShadowHeight`/`barShadowTop`, and `PlatinumDesktop` owns one `PlatinumBarShadow` window per screen (layer namespace `mountainous-bar-shadow`, no exclusive zone, empty input mask, visible with its bar). Extra dark stays flat. Platinum therefore maps three layer surfaces, not two; `theme-dev/win98/switch.sh` expects the shadow. `checks.bar-shadow` runs the window under labwc. The registered Platinum thumbnails predate the bevel. Evidence: `/tmp/ship-prep/shots/`.

## Tandem rule and parity ledger (from 2026-10-27)

**No workspace numbers are shown in either theme.** A page is named by its apps ("Beside Signal and Zed"), never by its number. See "No workspace numbers, and a steel Win98 dark caption".

Platinum and Windows 98 move together. A feature lands for both themes in the same phase, or this ledger records why one theme has no counterpart. New theme work updates this table when it lands. Fleet data, launches, windows and session actions stay in the shared owners; each theme draws its own view.

| Feature | Platinum | Windows 98 | Win98 counterpart |
|---|---|---|---|
| Status controls (Bluetooth, Wi-Fi, Sound, Brightness, OCI, Disks, builder gate, Notifications, Dictation, battery, clock) | Done | Done | Tray icons and windows |
| Theme picker | Done | Done | Display Properties |
| Pyxamp face | Done (`platinum`) | Done (`winamp`) | Pyxamp's Winamp face |
| Fleet window (Super+B, Super+O F) | Done | Done | Fleet window above the tray, tray Fleet icon, Properties sheet (see "Fleet window and glance space, Windows 98") |
| Glance space (Super+W) | Done | Done | Shut Down checker, caption animation, Glance taskbar button (same section) |
| Find menu and Go to Address (Super+P, Ctrl+L) | Done | Done | Find window above Start, IE's Open dialog (parity mock item 2; see "Find window, Open and web pages for Win98") |
| Window title bars | Done (hyprbars patch) | Done (caption; app icons pending) | Navy caption in light, steel in dark grey; minimize/maximize/close; the caption icon and Alt+Space open the window menu through `windows menu` (see "Windows 98 taskbar and session parity") |
| Chromium normal-window frame | Phase A (system frame, Chromium tabs) | Phase A (same) | Shared preference, GTK paint; outer-chrome roadmap below |
| Web page styling | Done (`themes/platinum/web.css`) | Done (`themes/win98/web.css`) | Win98 scroll bars and form controls; W95FA on buttons, drop-down lists and legends only |
| Session commands with confirmation | Done (Lock, Sleep, Log Out, Restart, Shut Down) | Done | Start ▸ Lock Myoko; Shut Down Myoko over the checker (Stand by, Shut down, Restart, Log off; remembered choice); Log Off's confirmation (see "Windows 98 taskbar and session parity") |
| About | Done | Done | Start ▸ Settings ▸ System...: System Properties ▸ General; one reader (`SystemFacts.qml`) for both themes |
| Hide, Hide Others, Show All | Done | Done | Minimize (the button stays, raised); the taskbar's menu: Minimize All, Minimize Other, Restore All (see "Windows 98 taskbar and session parity") |
| Window menu (Move to page, Hide, Close) | Done (tile menu) | Done | A button's right click, the caption icon, Alt+Space: Restore, Move to ▸, Minimize, Maximize, Close; pages named by their apps, never numbered (see "Windows 98 taskbar and session parity") |
| Held Super+Tab app cycling | Done | Done (over windows) | Alt+Tab Cool Switch box on the same `chrome cycle` messages (see "Windows 98 taskbar and session parity") |
| Recent Applications, pinned web apps | Done | Done | Start ▸ Documents (Recent Applications), Start ▸ Favorites (web apps), through `Launcher` |
| Volume and brightness change tag | Done | Done | A raised box above the tray icon, the block bar and the value, 1.5 s; Platinum's arming rules |
| Super+O N (Notifications) | Done | Done | The tray draws B W S L C D F R N; N opens Notifications under both themes |
| Native apps (GTK, Qt, Ghostty) | Built (five-appearance tandem phase below) | Built (same phase) | Chicago95 GTK, Qt Windows style; terminal fonts/reload superseded by [terminal fixes](desktop-themes/terminal-fixes.md) |
| Terminal monospace fonts and every-instance reload | Built (ProFontIIx Grid) | Built (Fixedsys Excelsior) | Grid-bold, Unicode/Nerd fallbacks; UI/tab fonts unchanged ([evidence](desktop-themes/terminal-fixes.md)) |
| Duplicate external display outputs | Built (mirror later matching connectors) | Built (same shared rule) | eDP-1 protected; one Quickshell Desktop per workspace destination ([evidence](desktop-themes/terminal-fixes.md)) |
| Icons, cursors, pattern | Phase 4, pending | Phase 4, pending | Win98 counterparts |
| Menu and system sounds | Built (original CC0 set, shared hooks and saved switch) | Built (original CC0 set, same hooks/switch) | See [phase4-sound-boot](desktop-themes/phase4-sound-boot.md) |
| Boot and shutdown | Built (fixed Platinum in initrd) | Original Win98 package built; fixed Platinum used at boot by choice (a) | No session ESP writes or switch-time rebuild; same section |
| State board, golden images, web drift check | Phase 5, not started | Phase 5, not started | Same checks, both themes |
| Verified on Myoko with real input | Yes (generations 50–52) | No (#13) | — |

`checks.theme-parity` (`modules/quickshell/theme-dev/theme-parity.js`, `node` only) holds both themes to this table for what the code can show. It reads what a Desktop exposes from the code itself: every method or flag `shell.qml` calls or reads on a Desktop (`reveal`, `cycle`, `toggleFleet`, `fleetShown`, …), whether the Desktop claims the omni view (`omniClaimed` and a `claimView()` call), whether `themes/<id>/web.css` exists, and whether the registry's picker exists and the Desktop loads it. It fails when one theme has one of these and another lacks it, unless the block below lists that gap with a reason; it also fails when a listed gap has closed, so the line goes when the piece lands. The table's rows that are not code (icons, native apps, verification on Myoko) are kept by hand.

```parity-gaps
# feature         missing in  reason
```

## Open items (from Simon's use on Myoko, 2026-10-28)

Each lands for both themes. New plan sections go in their own file under `docs/plans/desktop-themes/` (so parallel branches do not conflict here); this file keeps only the ledger and this list.

| # | Item | Notes |
|---|---|---|
| 1 | **Phase 4: icons, cursors, desktop pattern, menu sounds, boot screen** | Sounds and boot built: [part 2](desktop-themes/phase4-sound-boot.md). Icons, cursors and pattern remain separate work. |
| 2 | **Taskbar and strip page dividers are a plain divider**, no button at all | The number went; the empty button head is still there and reads as a stray empty slot. |
| 3 | **No soft fades.** Window and chrome motion follows the OS being mimicked | Win98: windows appear at once; minimize/restore/maximize use the caption animation; menus roll. Mac OS 8: zoom rectangles. Hyprland's default fade/pop-in goes under both themes. |
| 4 | **Built: terminal fonts and Ghostty live switching** | ProFontIIx Grid / Fixedsys Excelsior; real grid-bold and fallbacks. Reload reaches custom and NON_UNIQUE instances. GTK fractional-scale sharpness is still unverified. [Checks and evidence](desktop-themes/terminal-fixes.md); parent verifies Myoko. |
| 5 | **Chromium: every tab is a window** | No tab strip; the taskbar/Control Strip is the tab container. Explore memory cost. Supersedes the outer-chrome options B/C. |
| 6 | **Chromium captures Ctrl+L** in normal windows | Go to Address / Open should win. PWAs already behave. |
| 7 | **Installed PWAs keep Chromium's own title bar** | Forgerie is the exception (it launches as `--app=`). Wanted: one scalable rule for all web apps. |
| 8 | **Built: duplicate external outputs mirror one desktop** | Hot-plug rule matches description and mode, never touches eDP-1; Quickshell skips mirror/disabled outputs. [Checks and limits](desktop-themes/terminal-fixes.md); parent verifies the Myoko hub. |
| 9 | Win98 caption app icons | Generic document icon today. |

## Goal

Simon can switch the whole desktop chrome between a handful of themes: Mac OS 8 Platinum and Windows 98 first, more later. Each theme has its own bars, menus, controls, font and colours. The picker draws itself in the style of the current theme. A switch is live, with no restart and no logout.

## What a theme is

A theme is a set of prefixed QML files plus one entry in a list. Assets and pure policy code live in its folder. Phase 1 tried the original folder-based QML plan and used the specified flat fallback after the dynamic-load spike failed. It is not a palette file. Omarchy's model (one `colors.toml`, rendered into each app's config) cannot express a bevel, a bottom taskbar or a cascading Start menu. Its staging step, the live IPC switch, and the "on-screen apps first" order are still worth copying. See the Omarchy notes at the end.

| A theme decides | Platinum | Windows 98 |
|---|---|---|
| Which bars exist, on which edge | Top menu bar, plus the dock (restyled later) | One bottom taskbar, no dock |
| Where window switching lives | Dock | Taskbar buttons, banded by page |
| Launcher entry | Super+P drops the Find menu from the mountain (the omni service's Platinum view) | Super+P, Start ▸ Find and Run... open the Find window above Start (the omni service's Win98 view) |
| Status controls | Bar titles with readouts | Tray icons with tooltips |
| Menu shape and direction | Hangs down from its title | Rises from the tray; Start cascades up and right |
| Components | `Platinum*` set | New Win98 set |
| Font | ChicagoFLF | W95FA |
| Appearances | Light, dark grey, plus Extra dark (black bar) | Light (Windows Standard), dark grey |
| Picker view | Appearance control panel | Display Properties |

Shared by every theme, never forked:
- the data owners: Pipewire, Bluetooth, Wi-Fi, brightness, `OciEgress`, `StorageHealth`, `BuilderGate`, `Notifications`, `Dictation`, `Lanes`, the clock;
- the logic modules and their tests: `MenuState`, `battery.js`, `oci-model.js`, `notification-model.js`, `builder-gate.js`;
- what stays unthemed: the omni bar's service and its card (a theme may draw its own view of the service, see "Find menu" below), notification popups, the dictation overlay, app-specific content and non-GTK/Qt renderers (for example Zed).

## The three settings

| Setting | Values | Stored in | Exists today |
|---|---|---|---|
| Theme | `platinum`, `win98` | `$XDG_STATE_HOME/mountainous/theme-name` (missing = `platinum`) | No |
| Mode | `dark`, `light` | `.../mountainous/theme` | Yes |
| Extra dark | `on`, `off` | `.../mountainous/theme-extra` | Yes (on the Platinum branch) |

`desktop-theme` gains `desktop-theme set <theme>` and `desktop-theme list`. It writes `theme-name` under the same lock with the same atomic `mv`. `status` prints all three. Mode keeps driving GTK, Ghostty and dconf as today, for every theme.

A theme declares which settings it honours. Win98 has no Extra dark: its picker does not show the option, and the stored value is kept but ignored while Win98 is active. Nothing is lost when Simon switches back.

## QML structure

```
modules/quickshell/
  shell.qml                 shared owners per screen, transport and composition
  Theme.qml                 watched mode, extraDark and name; unthemed tokens
  themes.json               canonical registry used by Nix and QML
  ThemeCatalog.qml          synchronous registry reader
  ThemeDesktop.qml          two-slot per-screen loader and rollback
  ThemePicker.qml           persistent shared picker model
  panels/                   shared data owners, no theme imports or menu Components
  PlatinumDesktop.qml       complete one-screen top bar, menus and dock
  Platinum*Menu.qml          views receiving a shared `panel` data owner
  PlatinumTopBar.qml, PlatinumMenuHost.qml, PlatinumBarControl.qml …
  PlatinumTokens.qml        Platinum tokens reading Theme.dark / Theme.extraDark
  PlatinumPickerView.qml    Appearance control panel
  themes/platinum/
    previews/light.png, dark.png
    picker-plan.js          pure container policy and its test
  theme-dev/                excluded from host delivery
    fixtures/               disconnected data inputs, alternate and broken Desktops
    lifecycle.test.js       actual Platinum, rollback, CLI picker and 20 swaps
    check-boundaries.py     registry and cross-theme dependency checks
```

1. **Data and view split.** The eight shared owners remain in `panels/`. Every moved view has `required property var panel` and reads that owner's existing public properties and methods. `StorageHealth.findings` exposes its existing ListModel; its colour mapping moved into the Platinum view. Data owners never import a theme.
2. **Per-screen loader.** `shell.qml` retains one `Variants` over screens and instantiates `ThemeDesktop` beside each screen's owners. It compiles the requested entry point asynchronously, then uses the inactive Loader slot. Every window of the candidate starts hidden. Only Ready activates it and unloads the old slot. Dock lane ordering, refresh and drag dispatch logic stay shared.
3. **Tokens.** Platinum views read `PlatinumTokens`, including the unchanged dock palette. Shared `Theme` retains mode, extra, name and unthemed overlay tokens. Its theme-neutral diagnostic string preserves `theme current`'s existing bar/rule words without retaining Platinum tokens there.
4. **Spike result: use flat QML.** The first static spike passed: `import "sub"` resolved a component and its sibling singleton without a `qmldir`. The actual dynamic-loader test then failed: local menu types were not discovered. Removing the old root preview's static Platinum import exposed the failure. A minimal `Qt.createComponent("sub/View.qml")` spike confirmed `ReferenceError: Tokens is not defined`. Evidence: `/tmp/themes-p1/spike.log`, `/tmp/themes-p1/spike-dynamic.log`, `/tmp/themes-p1/dynamic-spike.log`. The exact flake package is Quickshell 0.3.1 at `gvgrz4bh8hryjzrvkqjiwyh4acpn27aj`. Flat `Platinum*` files work under the real dynamic loader. **Do not restore subfolder QML without repeating the dynamic spike. Do not add a root qmldir.**
5. **Delivery.** `modules/bars.nix` already collects recursively. It now includes the root registry and all non-development files below `themes/`, including thumbnails. `checks.bar-delivery` requires `PlatinumDesktop.qml`, `themes.json` and a nested preview, and rejects development fixture delivery. The boundary check handles both flat type prefixes and asset-folder imports.

## Switching live

```steps
1. Simon picks a theme in the picker (or runs desktop-theme set win98)
   desktop-theme writes theme-name atomically.
2. Theme.qml sees the file change
   Theme.name changes.
3. Each screen builds the new Desktop next to the old one
   A second Loader loads asynchronously. The old Desktop stays on screen until the new one reports Ready.
4. Swap
   The new Desktop is shown, then the old one unloads. MenuState closes any open menu first.
5. Hyprland follows
   The exclusive zone moves. Windows resize once.
```

If the new Desktop fails to load (a QML error), the old one stays, `theme-name` is rolled back, and a notification names the error. A broken theme must never leave Myoko with no bar.

## The picker

One registry in `themes.json`, read by `ThemeCatalog.qml`, and one shared model in `ThemePicker.qml`: the list of themes, their appearances and options, the current choice, `preview(theme, mode)` and `apply()`. Each theme supplies its view, registered by the `picker` path in `themes.json`:
- Platinum: the Mac OS 8.5 Appearance control panel. Click applies at once, as on Mac OS 8.
- Win98: Display Properties, Appearance tab. The preview pane changes on selection; OK and Apply commit; Cancel reverts.

Previews of other themes are static images registered in `themes.json` (made by the build's screenshot sweep), so the picker never loads a second theme's QML to draw a thumbnail.

Every theme must open the picker from all of: its own menu (Platinum clock menu, Win98 Start > Settings > Display), the omni bar command "Desktop theme...", and `desktop-theme`. A check enforces that each theme wires all three.

## Keyboard and Hyprland

`hyprland.lua` today calls `qs -c mountainous ipc call topbar reveal` for the Super+O chord. That name is Platinum's. The `chrome` target now forwards `reveal`, `hide`, and `open <control>` to the active Desktop. `topbar` remains an alias; `chrome toggle` retains the whole-chrome immersive toggle. Win98 maps the same chord letters to its tray icons, and Ctrl+Esc opens Start (`chrome open start`). Platinum adds N for Notifications; the bind checks `theme-name` and passes N through under Win98, so Win98's letters are unchanged (see "Quiet glyphs" below). Super alone is not bound; see the phase 2 decisions.

## Fonts

ChicagoFLF and W95FA Grid are installed on every desktop host (`modules/fonts.nix`, merged from `win98-font`), so a switch never waits for a font. W95FA comes from the `w95fa-src` flake input (`flake = false`); `scripts/w95fa-grid.py` snaps it to its pixel grid as "W95FA Grid", and `checks.w95fa-grid` verifies the family name, the grid and the unchanged OFL text (its template copyright line is recorded in the input's comment). The Win98 Desktop names the packaged family; only the development gallery uses a FontLoader.

## Checks

- The existing per-control and sweep checks run once per theme, both modes.
- `scripts/test-desktop-theme` gains `set`, `list`, rollback and the ignore rule for Extra dark.
- A delivery check: every file under `themes/` reaches Quickshell; no theme imports another's tokens.
- A switch test in headless Quickshell: switch Platinum to Win98 and back 10 times; no QML warnings, no leaked windows, exclusive zone on the right edge each time.

## Phases

| Phase | Result | Visual change |
|---|---|---|
| 0 | Platinum lands on `cairn` (someone else) | Platinum |
| 1 | Data/view split, per-screen loader, `theme-name`, `chrome` IPC, picker in Platinum style | None except the new picker |
| 2 | Win98 theme from the approved mockup and state boards (implemented, see below) | Win98 selectable |
| 3 | Apple menu, Application menu and Control Strip (implemented, see below) | Platinum dock becomes the Control Strip |

Phase 1 is a refactor with no visible change, so its review is a pixel diff of the Platinum sweep before and after.

## Risks and costs

- Phase 1 touches every panel file that the Platinum branches just changed. It cannot start before Platinum lands.
- Two themes double the screenshot sweep and the review work for any later bar change.
- The swap shows two bars for one frame at most, and windows resize once when the bar changes edge. I do not know yet how Hyprland animates that resize.
- Static subfolder discovery passed, but dynamic discovery failed. Phase 1 uses the flat-prefix fallback above.

## Omarchy notes (verified at omacom/omarchy 967bbdd, v4.0.6)

- A theme is `themes/<name>/` with `colors.toml` (palette plus `mode`), optional `shell.toml` (sizes, border widths, alphas, gradients) and per-app overrides.
- `omarchy-theme-set` stages into `next-theme`, renders `default/themed/*.tpl`, swaps with one `mv`, then sends the palette to the running Quickshell over IPC.
- Apps on screen retint first; the rest retint in the background.
- Light and dark are separate themes; there is no mode switch.
- Taken here: atomic staging, live switch without restart, on-screen first. Not taken: palette-only themes.


## Phase 1 public contract (for phase 2)

### Registry

Add one entry to `modules/quickshell/themes.json`. It is the only installed-theme list. Nix reads it for CLI validation and `list`; QML reads the same file. `packages.<system>.desktop-theme` exposes a native command for each check platform; the installed NixOS command uses the same factory.

| Field | Platinum value / contract |
|---|---|
| `id` | `platinum`; lower-case slug |
| `label` | `Mac OS 8 Platinum` |
| `pyxampFace` | `platinum` for Platinum; `winamp` for Win98. Required; only these two values are valid. Pyxamp reads the delivered registry and `theme-name`, falling back to `platinum` for a missing/unknown name. |
| `qmlPrefix` | `Platinum`; use `Win98` for phase 2 |
| `desktop` | `PlatinumDesktop.qml`; root-level prefixed file |
| `picker` | `PlatinumPickerView.qml`; root-level prefixed file |
| `appearances` | `{mode: "light" or "dark", label, thumbnail}` per supported appearance |
| `options.extraDark` | `true` for Platinum; `false` for Win98 |

Thumbnails are static PNGs under `themes/<id>/previews/`. Register each path in its appearance. The current thumbnails are crops of the real headless bar and Sound menu, not drawings or another theme's QML. QML delivery finds them recursively.

### Desktop

The loader supplies these properties at construction, before QML evaluates required bindings:

| Property | Contract |
|---|---|
| `required property var screen` | This screen's Quickshell ShellScreen; kept live |
| `required property var context` | This screen's shared owner object; kept live |
| `required property var theme` | The registry entry being loaded, not the requested global name |
| `property bool active: false` | Every window must remain hidden/non-reserving while false. The loader sets true only on Ready. |
| optional `readonly property string diagnostics` | Extra words for `theme current`; Platinum reports ` bar=… rule=…`. No palette belongs in shared Theme. |

`context` contains `bluetooth`, `wifi`, `sound`, `brightness`, `oci`, `storage`, `builder`, `centre`, `notifications`, `dictation`, `omniBar`, `builderGate`, `frontWindow`, `now`, and `shell`. The first eight are shared per-screen data owners. The services and clock retain their existing owners. No view owns another copy of their data.

`context.shell` supplies `chromeVisible`, `chromeAccessVisible`, `builderKeyboard`, the shared menu methods (`openMenu`, `toggleMenu`, `closeMenu`), and dock helpers (`windowsOn`, `pageOf`, `dropOnto`). A theme may omit the dock. The menu selection remains the shared `MenuState` singleton.

Each Desktop implements these methods. It must **not** register an IPC handler per screen; root handlers are reliable in Quickshell 0.3.1 and forward to the selected instance.

| Method / transport | Contract |
|---|---|
| `reveal()` / `chrome reveal` | Reveal chrome and its keyboard-access hints. |
| `hide()` / `chrome hide` | Hide keyboard-access hints, not the immersive whole-chrome toggle. |
| `open(control)` / `chrome open <id>` | Open the requested control. Ignore unsupported/disabled IDs. |
| `chrome toggle` | Shared whole-chrome visibility toggle; unchanged Super+I behaviour. |
| `topbar reveal`, `hide`, `open` | Compatibility aliases for the theme-neutral routes. |

The stable IDs are `bt`, `wifi`, `vol`, `bri`, `oci`, `disk`, `builder`, `ntf`, `clock`, `more`, and `theme` (picker). Existing chord routing is preserved: hardware controls use the primary screen; builder, notifications and picker follow focus. Existing per-control IPC targets remain available. Hyprland's Super+O chord now uses `chrome` for the hint and control routes.

A candidate must create all chrome in its Desktop and honour `active`. A compilation/creation error keeps the old object, closes the menu, calls `desktop-theme rollback <failed> <previous>`, and sends one primary-screen notification with the failed ID and Qt error. The fixture's broken type is never delivered to hosts. Runtime binding warnings are not a Loader Error: each new theme must still pass the warning-free engine test.

### Picker view

The Desktop's picker Loader reads `theme.picker`, passes `{screen, model: ThemePicker}`, and loads it only when the Desktop is active and `ThemePicker.screen` matches. The shared model persists across swaps; a theme must not reset it.

The view receives `required property var model` and the Quickshell window's `screen`. Model properties are `themes`, `choices`, `currentTheme`, `currentMode`, `extraDark`, `applying`, `error`, `visible`, and `screen`. Methods are `open(screen?)`, `close()`, `preview(theme, mode)`, and `apply(theme, mode, extraBoolean)`. Apply runs `desktop-theme apply …`; only watched state files establish the current choice. Win98 can keep a view-local draft for its Apply/Cancel convention and call the same method only on commit.

A theme without Extra dark hides that option and preserves the stored value. Platinum disables the option in light mode, as before. Error text and Extra dark stay in the scrollable body. Close is pinned only when the remaining viewport can fit a complete labelled choice; otherwise Close joins that body. Short windows drop the title and tab decoration and show labelled text choices instead of thumbnails. Very narrow option rows stack the label and checkbox rather than retaining a wide gutter. Tab/Enter/Space select themes, E toggles Extra dark, and Escape closes. `desktop-theme picker`, the omni command and the clock item all open the same model. Only Themes is implemented; the mock's inert Appearance/Scale tabs are not added as non-functional controls.

## Phase 1 decisions and evidence

| Choice | Reason / cost |
|---|---|
| Flat prefixed QML; asset subfolders retained | Dynamic folder discovery failed without qmldir. This increases the root file count but avoids a hidden static-import dependency. |
| JSON registry instead of a JS-only list | Nix and QML parse one source without generation or duplicate IDs. |
| `desktop-theme picker` and `apply <theme> <mode> <on/off>` | Preserve the existing no-argument toggle. Apply serializes all three preferences under the existing lock. |
| `status`: `mode=dark extra=off theme=platinum` | Explicit field names; scripts parsing the old one-word status must change. |
| Async preflight compilation plus two Loader slots | Qt's component errorString supplies a useful rollback notification. A Ready candidate replaces the old slot only once. |
| Hardware chord routes remain primary-screen routes | Preserve existing behaviour rather than silently changing multi-screen focus policy. |
| W95FA deferred to phase 2 | No installed theme uses it in phase 1. The original licence/input guidance still applies when adding Win98. |
| Controlled fixture clocks and a raster app icon in the capture harness | Avoid the storage timer becoming stale mid-sweep and per-process external SVG raster noise. Production helpers, views and palettes remain the actual files. |

Final visual evidence is under `/tmp/themes-p1/before/` and `/tmp/themes-p1/after/`, with exact comparison results in `/tmp/themes-p1/pixel-diffs.json`. The capture size is 1920×1200 logical at 1.5 (2880×1800 PNGs). Thirty of the 33 bar/menu comparisons are byte-pixel-identical. The three clock menus differ only for the new Desktop theme item and the resulting menu height/hint position. The 1920-wide overflow menu has no overflow entries. Picker geometry is now checked separately in the real engine; the picker ladder does not substitute for compositor-level chrome assertions.

The final sweep uses production `MenuState.qml`, `bar-plan.js`, `battery.js`, and `oci-model.js` from a05c2ead, not the old session's temporary stubs. The renderer is Qt Quick software inside an isolated Wayland-only Hyprland. To force its fallback safely, set `LIBSEAT_BACKEND=seatd`, a nonexistent `SEATD_SOCK`, and a nonexistent `AQ_DRM_DEVICES`; verify its log has no `drm: Starting backend` before creating any output. Nix checks must use `--option builders ''` when host access is forbidden.

Picker ladder evidence: `/tmp/themes-p1/picker-ladder/{full,half,narrow-tall,wide-short,tiny,160x80,very-narrow-tall}.png`, covering 1920×1200, 960×600, 240×800, 1200×180, 160×150, 160×80 and 80×800 logical. The `160x80-close.png` and `160x80-extra.png` frames show focus scrolling each control fully into view. JSON geometry snapshots accompany the images. The one installed theme has exactly two appearance choices. Zero installed themes is rejected by the registry check. Larger lists and Win98's deferred-apply interaction require a new phase 2 ladder.

`checks.desktop-theme-shell` runs the actual Platinum Desktop without qmldir, opens the picker through the packaged CLI, rejects the broken fixture with a captured notification, and completes ten Platinum → alternate-fixture → Platinum rounds. It checks a single loaded slot, missing/unknown state, and no QML scene warnings. Missing sandbox PipeWire/UPower services can emit transport diagnostics; no service is contacted on a fleet host. The cross-theme check has also been exercised with an intentionally forbidden import.

The focused checks are `desktop-theme`, `desktop-theme-shell`, `bar-delivery`, `bar-model`, `builder-gate-view`, `notification-view`, and `dictation-lifecycle`. The Myoko toplevel evaluation is recorded at `/tmp/themes-p1/myoko-toplevel.txt`. The full flake check was interrupted during evaluation. The project then changed `AGENTS.md` to prohibit every flake check after RAM/swap exhaustion. It was not restarted. That incomplete log is `/tmp/themes-p1-flake-check.log`; it is not a passing full check. Focused attributes remain the validation boundary. A subsequent bounded aarch64 package evaluation timed out under memory pressure; no ARM build was run.


## Review fixes and phase 2 gates

The review's 160×80 failure was reproduced in the engine: the original choice viewport was −11px high. The picker now budgets the container height before adding chrome. Below the gallery budget it uses complete labelled text choices; below the compact-list budget the entire body scrolls, including Close. The 160×80 viewport is now 60px high. The compact header waits for a 112px list-well budget (100px after insets), and very narrow wrapped rows use the whole-body structure. The engine asserts a complete choice fits before allowing a pinned header. `picker-geometry.test.js` checks non-negative viewports, horizontal bounds, scroll extents, focus-driven reveal, complete labels, 0/1/12 choices, and error text at the size ladder and both sides of each structural boundary. Gallery rows and pinned-header rows must fit a complete choice; taller wrapped rows are allowed only in the whole-body scrolling structure.

The development capture scripts share `stage-runtime.sh`. It stages runtime files recursively, including `panels/`, theme policies, icons and previews, but excludes all three development directories, executable helpers and tests. Their bootstrap Nix commands disable remote builders. The storage-preview runbook resolves QtWebSockets from this flake's pinned Myoko package and adds the same QML import path as the service.

**Before Win98 ships, phase 2 must add and prove all of the following. None is implemented as part of these review fixes:**

- Add a stable `start` control ID to the theme-neutral Desktop/IPC contract. Route Super alone and Ctrl+Esc to it while Win98 is active. A used Super chord, such as Super+O, must not open Start when Super is released. Preserve Platinum's existing routing while Platinum is active.
- Test upward-opening tray menus and cascading Start menus at screen edges, short heights and narrow widths. Prove pointer handoff between cascades; Right/Left/Enter/Escape focus movement; disabled-item skipping; return of focus when a child closes; and closing every cascade when a theme is replaced. No cascade may lose its focus grab or become clipped/unreachable.
- Assert actual compositor exclusive zones and mapped-window counts, not only Loader slot counts. After each of at least ten Platinum ↔ Win98 round trips, assert the correct reserved edge and usable area, no extra dock/bar from the old theme, and no leaked menu/picker/cascade windows after destruction settles. A broken candidate must preserve the previous theme's zone and window count.
- Repeat dynamic component discovery and warning-free load tests when integrating the separately developed `themes/win98/Win98*.qml` components. Keep `themes/` and let the phase 2 merge own its SVG-delivery changes. Do not rely on a static import of another theme to make discovery pass.

Run these as bounded headless tests and focused single-attribute checks, never as a full flake check or a live deployment.


Review validation evidence lives under `/tmp/themes-p1/review/`. `picker-before.log` records the −11px reproduction; `picker-after.log` records 27 geometry cases with the original and new boundaries, counts and errors. The single `checks.x86_64-linux.desktop-theme-shell` build also runs those assertions, the picker policy tests, runtime-staging tests and the existing real-Platinum rollback test. `storage-runbook.log` records the documented headless preview loading four ready findings. The complete notification and builder capture scripts produced 50 and 178 PNGs respectively in `notification-capture-final/` and `builder-capture-final/`; neither log has missing-type/import failures. Notification stress scenarios deliberately include a nonexistent image, which can emit image-load warnings. The picker engine and new ladder have no QML scene warnings. ShellCheck, QML lint and parser checks passed. No full flake check, deployment or push was run for these fixes.


## Phase 2: Windows 98 (implemented)

Simon can pick "Windows 98" in either picker (or run `desktop-theme set win98`). Each screen's chrome becomes one Win98 taskbar on the bottom edge, with the Start menu, tray windows, tooltips and Display Properties. The switch is live through the phase 1 loader, and it switches back to Platinum the same way. Spec: the approved mock at `/tmp/win98-mock/` (`REPORT.md`, `STATES.md`, the state sheets).

### What was built

| Part | Files |
|---|---|
| Control library (merged from `c-341adb…`, moved flat) | `Win98*.qml` controls; icons in `themes/win98/icons/`; gallery and scripts in `themes/win98/dev/` (not delivered) |
| Font (merged from `win98-font`) | `modules/fonts.nix` `w95fa-grid`, `scripts/w95fa-grid.py`, `tests/w95fa-grid.py` |
| Desktop | `Win98Desktop.qml` (contract, selection, tray data, Start model), `Win98Taskbar.qml`, `Win98MenuHost.qml` (Start, chevron menus, tray windows, Log Off), `Win98TipWindow.qml` |
| Tray windows | `Win98SoundWindow`, `Win98BluetoothWindow`, `Win98WifiWindow`, `Win98BrightnessWindow`, `Win98OciWindow`, `Win98StorageWindow`, `Win98BuilderWindow`, `Win98NotificationWindow`, `Win98DictationWindow`, `Win98ClockWindow`, `Win98LogOffDialog` |
| Picker view | `Win98PickerView.qml` (Display Properties), `Win98Preview.qml` (a scheme drawn in its own palette) |
| Pure policies and tests | `themes/win98/taskbar-plan.js` (+ `.test.js`), `tray-model.js`, `start-model.js` (+ `models.test.js`) |
| Registry | `themes.json` entry `win98` (`qmlPrefix` `Win98`, `options.extraDark` false), thumbnails `themes/win98/previews/{light,dark}.png` cut from the real Desktop |
| Keyboard | `modules/hyprland/hyprland.lua`: Ctrl+Esc opens Start while `theme-name` is `win98` |
| Harness and checks | `theme-dev/win98/` (harness, mock state catalogue, capture, behaviour, switch, virtual pointer); `checks.win98-desktop` |

Every view reads the shared owners in `context` and owns no data. The one menu or window open at a time is the shared `MenuState`, across screens. The Desktop does not register IPC handlers; `chrome open start` reaches it through the root `chrome` target. The window buttons use the shell's `windowsOn`, `pageOf` and `dropOnto` (lanes.js), not a copy.

The layer surfaces: the taskbar (`mountainous-taskbar`, always mapped while active; it reserves `ceil(28 u)` = 38 logical px), the menu host (`mountainous-menu`, only while a menu, window or taskbar keyboard focus exists), the tooltip (`mountainous-tooltip`, overlay, no input, only while a tip shows) and the picker (`mountainous-picker`, only while open). A layer surface is a whole number of logical px tall and 28 u is not, so the taskbar surface takes the next height whose physical size is whole and draws the bar on its bottom edge; small surfaces (tooltips) are full-screen and transparent so they land on whole physical pixels.

### Decisions made without asking

| Decision | Reason / cost |
|---|---|
| A lone Super is not bound; Ctrl+Esc opens Start | Kanata's held Space is Super, so a lone Super release would fire whenever a held Space timed out. Ctrl+Esc reads `theme-name` in Lua and declines (passes the keys on) under Platinum, so Platinum's routing is unchanged. Cost: Win98 users have no one-key Start. |
| Urgency is real, not stubbed | Quickshell 0.3.1's `HyprlandToplevel` has `urgent` (qmltypes). A button flashes navy every 500 ms for seven phases, then stays lit until the window is focused. Not tested against a live urgent window. |
| Taskbar keyboard focus exists, but only from the keyboard | The mock's "focus" column needs reachable states, and decision 8 kept Super+O. Esc from a Start menu the keyboard opened leaves the focus on Start, as Win98 did: Left/Right/Tab move along the bar, Enter/Space/Up open, Esc lets go. Pointer use is unchanged. |
| Hover switching includes Start, both chevrons and the clock | As the mock's `MENU_IDS`. |
| Log Off runs `hyprctl --instance 0 dispatch hl.dsp.exit()` after Yes | The same dispatcher as Super+Shift+E. |
| Start > Settings opens Bluetooth, Wi-Fi, Sound and Brightness even when their hardware is missing | Their windows say why; this closes flag 28 (hidden controls only reachable by Super+O) for pointer users. |
| Programs: freedesktop main category → Win98 folder (Accessories, Development, Education, Games, Graphics, Internet, Multimedia, Office, System, Other) | When every app lands in one folder, Programs lists the apps flat, so the mock's 63-app column state is reachable. Known apps get Win98 icons; others `doc`. |
| Commands: the omni bar's rows without the theme rows and "Go to window"; the three scale rows cascade | As the mock. "Desktop theme..." is Start > Settings > Display.... |
| The builder's manual choice latches its tray button (sunken over the dither) | The mock shows it; `builder-gate.js` dropped `latched()` for Platinum's bar titles, so the rule (`choice !== null`, nothing pending) lives in the Win98 Desktop only. |
| Display Properties: its own theme first in the Theme list, then the registry order | Matches the mock's list in both states. |
| Another theme's preview is its registered thumbnail | The contract forbids loading another theme's QML. The mock drew a Platinum sketch; the build shows Platinum's real thumbnail. |
| Extra dark is not offered in Display Properties | Win98 has none; Apply passes the stored value through, so Platinum finds it again. Platinum's own picker still has it. |
| The Scale tab holds Scale up / Scale down / 100% (`hypr-scale`) | The mock showed the tab but not its content; phase 1 rejected inert tabs, so it does what the omni bar's scale rows do. |
| Initial focus in Display Properties is the dialog; OK is the default button; Alt+T, Alt+S, Alt+A, Ctrl+Tab | The mock shows no focus ring until Apply is focused. |
| Notification relative times use the Desktop's minute clock (`context.now`) | Deterministic in the harness; "4 min" needs no finer step. |
| The chevron menus and the tooltip appear at once; Start rolls up and cascades roll right in 120 ms | The mock's motion spec (DIRECTION.md); the library's `Win98Tokens.reducedMotion` turns it off, but nothing in the session publishes reduced motion yet. |
| Window order inside a page is the compositor's | lanes.js sorted unstably under Qt's engine (Signal and Zed swapped in the first render). The fix breaks ties by position; it is shared, so the dock gains it too. |
| The taskbar plan measures text one unit wide | The mock's canvas measured every string just over its whole pixels and rounded up; matching that makes the yields happen at the mock's widths. Drawn widths are exact. |
| Horizontal centring to the half unit | The mock centred boxes and text runs without snapping across; a half unit is still one whole physical pixel. Vertical positions keep the library's whole-unit snap. |
| Menu shortcuts end on one edge; a menu is as wide as its widest label-and-shortcut pair | The mock's flex rows. This changed the library's left-aligned shortcut column. |

### Review fixes (after the phase 2 review)

| Decision | Reason / cost |
|---|---|
| A cascade opens right, else left, else over its parent, clamped inside the screen | Win98 did the same. Over the parent, the parent's lower rows are hidden until the cascade closes; Left or Esc closes it. |
| A many-column menu takes at most as many 80 u columns as fit across the screen, then scrolls with Win98's arrow strips (hover, 80 ms a row; wheel) | Win98 scrolled long menus with arrow strips. At 160 px the 63-app Programs list is one column and scrolls. Cost: a scrolled row is two moves away. |
| Disabled items are skipped by Up, Down, Home, End and access letters | Win98 never selected a grey item. Start > Windows with no windows opens with nothing selected. |
| Taskbar ladder after the tray chevron: the focused window goes, then the clock, then the battery move into the chevron; then a compact bar (Start plus one chevron with the tray controls, the windows, the clock and the battery); then Start alone, whose menu gains a "T&askbar" cascade with the same list | Readouts go before controls (review item 4). Start > Windows already lists every window. The battery row in the chevron is an inert readout, like the clock's. |
| `MIN_WIDTH` = 28 u (37 logical px at 1.5): the plan fits at every width from there | Start's smallest face is 28 u. Below that the plan still says `fits: false`, Start narrows to the bar, and everything stays reachable through it. |
| A short screen: lists give up rows first (Bluetooth and Wi-Fi 140 → 72 u, Storage 120 → 40 u, Notifications 260 → 80 u, OCI 5 → 2 rows, Sound's slider 50 u), then the status or key-hint bar goes, then the body scrolls with the focused control kept in view; the caption and the action buttons stay | Review item 2: primary actions stay; decoration goes before scrolling. Each window's natural height is measured once after layout (`Qt.callLater`), not bound, to avoid a binding loop. Cost: a resize redraws one frame later. |
| Display Properties narrow: labels above their lists, OK/Cancel/Apply stacked right; short: the preview shrinks then hides below 40 u, the note goes, then the dialog scrolls and follows keyboard focus | Review item 3. |
| A narrow Start menu (under 160 u of room) uses 20-u rows with 16-u icons; under 140 u the "Kamoi" band goes too | Decoration gives way before the labels: at 160 px the 32-u rows left the labels only their three dots. |
| Property-sheet tabs that do not fit wrap into rows, the current tab's row on the sheet, rows 20 u apart, each row's tabs stretched to its width | Win98's multi-row sheets. At 160 px the Scale tab was cut at the dialog's edge. The 20 u step (not 18) keeps the raised current tab off the label above it. |
| On a short screen the action buttons inside a window's group box scroll with the body; they are not pinned | Win98 never pinned them; Enter (or the window's letter keys) runs the action wherever the button is, and keyboard focus scrolls it into view. Cost: with the pointer, a 180 px screen needs one scroll to reach Connect. |
| Each window draws in its own unit (`Win98Tokens.unitFor(window)` = 2 / the window's device pixel ratio) | Two outputs at different scales (Myoko plus the Sunshine tablet) each get 2-px bevels. Done now rather than noted, because it was 136 mechanical call sites. |
| Layer surfaces are counted with niri, nested in the headless sway | `niri msg --json layers` lists every mapped layer-shell surface with its namespace; sway's IPC lists none, and a nested Hyprland stalled (see Not verified). niri runs on Mesa's llvmpipe; sway still supplies the usable area and the pixels. Cost: Hyprland itself is not the compositor counted. |
| `checks.win98-desktop` renders through Mesa's llvmpipe, not Qt's software renderer | Qt's software renderer drew 1.5-scale bevels as 3 + 2 + 3 px; `scales.sh` caught it. |

### Evidence

All renders are headless: sway's headless backend with the pixman renderer, private runtime, state, config and cache directories, no DRM output, Qt on llvmpipe. The live Quickshell was not touched.

| Gate | Result | Evidence |
|---|---|---|
| Every mock state, both appearances, 2880x1800 at 1.5 | 227 states x 2 rendered from the real QML, recaptured after the review fixes. Against the mock, every sheet's median is unchanged from before the review (largest per-state change +0.27 points, `m-ntf-kinds`, whose notification image is the capture's own thumbnail). Against the pre-review captures, 38 of 454 images differ: caption gradients by 1/255, `s-long` where Obsidian no longer borrows the OBS icon, and that thumbnail | `/tmp/win98-desktop/states/{light,grey}/*.png` (pre-review: `/tmp/win98-desktop/states-before-review/`); side-by-side mock/build crops and per-state pixel counts in `/tmp/win98-desktop/compare/` (`summary.tsv`; pre-review `/tmp/win98-desktop/summary-before-review.tsv`); differences in `/tmp/win98-desktop/review3-vs-before.txt` |
| Behaviour (the mock's `bin/check.sh` list plus Cancel/Apply, and the disabled "(No windows)" item) | 33 of 33 pass against the real QML with a virtual pointer and keyboard, in the build sandbox | `theme-dev/win98/behaviour.sh`, run by `checks.win98-desktop`; log `/tmp/win98-desktop/checks-win98-desktop.log` |
| 10 x Platinum ↔ Win98, compositor level, then a broken Win98 | 107 of 107 pass. Before every swap a transient surface is open (rotating: a Start cascade, Programs > Internet; the Sound window; Display Properties; under Platinum the volume or clock menu, or its picker). Under sway: the usable area starts 28 px down for Platinum and ends 38 px up for Win98, no old chrome on screen, one loaded slot, no QML warnings. Under niri, after each swap, the mapped layer surfaces are exactly the new theme's (`mountainous-taskbar`; Platinum's two `quickshell` bars) plus the picker when it was open, and no menu, cascade, tooltip or old bar; the transient was mapped before the swap. The broken Win98 keeps Platinum (the same two surfaces, its open menu closed), writes `platinum` back and sends one notification naming the error | `theme-dev/win98/switch.sh`, run by `checks.win98-desktop`; logs `/tmp/win98-desktop/checks-win98-desktop.log`, `/tmp/win98-desktop/switch-run.log` |
| Platinum unchanged | 33 phase 1 Platinum states, phase 1 code (b7f20f04) against this branch, rendered in the same session: four pixels differ by more than 1% in a channel, all in the three notification captures (`{light,dark,extra}/ix-ntf-open.png`), and the largest channel difference is 3/255. The same phase 1 code rendered twice gives the same four pixels and 3/255, so they are llvmpipe noise. After the review fixes the branch again differs by at most 3/255 (8 pixels above 1%, the same three captures) | `/tmp/win98-desktop/plat/{before,before2,after,after2}/`, `/tmp/win98-desktop/plat/maxdiff.py` |
| The Platinum picker lists Win98 | 4 choices, Win98 thumbnails from the real Desktop | `/tmp/win98-desktop/states/switch/6b-picker-platinum-*.png`, `6c-switch-*.png` |
| Pixel rules in the full desktop | Every bevel line is 2 physical px (taskbar edge and Start button columns: `DFDFDF` 2, `FFFFFF` 2, ..., `808080` 2, `000000` 2); the clock's text crop has exactly two colours (`#000000`, `#C0C0C0`), so no glyph edge is blended | `/tmp/win98-desktop/states/light/tb-normal.png` |
| Narrow widths | `taskbar-plan.test.js` walks 1440 u down to 1 u with 0, 1, 5 and 12 windows, with and without dictation: `fits` at every width from `MIN_WIDTH`, every part inside the bar and in order, the task buttons inside their box, steps only grow, and every window, tray icon, the clock and the battery stay reachable | `checks.win98-desktop` |
| Real bounds at small sizes | 50 of 50 pass, read from the live QML items: the taskbar at 1920, 600, 320, 160, 80, 56 and 40 px wide in three states (no part off the bar or overlapping); Start cascades at 320 and 160 px and Programs > Accessories by keyboard at 320x600 (inside the screen); every tray window, the clock, Log Off and Start at 1200x180 (inside the room above the taskbar, buttons visible or the body scrolls); Display Properties at 160x800, 160x80 and 1200x400 (OK, Cancel, Apply and both tabs inside, tab labels uncovered; focus scrolled into view); at 1920x1200 no Start panel scrolls or sits scrolled | `theme-dev/win98/geometry.sh`, run by `checks.win98-desktop`; screenshots of the review's cases in `/tmp/win98-desktop/review-shots/` |
| Two outputs at scales 1.5 and 1 | Both taskbars draw the Start button's column with 2-px bevel lines (`2#dfdfdf 2#ffffff 4#c0c0c0 2#ffffff 2#dfdfdf 36#c0c0c0 2#808080 2#000000 4#c0c0c0`) | `theme-dev/win98/scales.sh`, run by `checks.win98-desktop` |

After the review fixes, `win98-desktop` (`/tmp/win98-desktop/nix/win98-desktop.log`), `win98-theme`, `desktop-theme-shell` and `bar-delivery` were rebuilt and pass (`/tmp/win98-desktop/nix/summary-review.txt`). Before them, focused Nix checks, one at a time with `--option builders ''`, all passed: `bar-model`, `bar-delivery`, `dictation-lifecycle`, `notification-view`, `desktop-theme`, `desktop-theme-shell`, `builder-gate-view`, `win98-theme`, `w95fa-grid`, and the new `win98-desktop` (`/tmp/win98-desktop/nix/summary.txt` and one log per check beside it). `nix eval --option builders '' .#nixosConfigurations.myoko.config.system.build.toplevel.drvPath` succeeds (`/tmp/win98-desktop/nix/myoko-toplevel.txt`); Myoko's `fonts.packages` contain `chicagoflf` and `w95fa-grid`. No full flake check, deployment, ssh or push was run.

### Where the build differs from the mock

Per-state counts compare the bar strip and the mock's menu, window and tooltip boxes; the backgrounds differ by design (the mock painted app windows; the captures show the Win98 desktop colour). Medians by sheet: 1 (taskbar) 1.6%, 2 (controls) 1.6%, 3 (tray data) 1.4%, 4a to 4e (windows) 2.9 to 6.6%, 5 (Start) 3.6%, 6 (picker) 16.3%, 7 (widths) 3.4%. Every visible difference reviewed:

| Difference | Why |
|---|---|
| Antialiased edges of round and diagonal icons, and the caption gradients | Qt's SVG and gradient rasterisers differ from Chrome's. Qt's SVG renderer ignores `shape-rendering="crispEdges"`, so the diagonal strokes in the terminal, Zed and Commands icons are antialiased where the mock's are aliased. Bevels, text and patterns are exact. |
| Platinum previews in Display Properties (sheet 6, the largest counts) | The contract shows another theme's registered thumbnail; the mock drew a Platinum sketch. |
| Bluetooth and Wi-Fi windows say Stop / "(scanning)" | The shared panels start discovery whenever their window is shown; the mock's not-scanning windows are a state the data owners never show while open. |
| Storage shows "Checking" | The harness's stand-in `storage-health-status` never exits, so the real `StorageHealth.checking` stays true. |
| Wi-Fi password prompt selects the network it asks about | The mock selected another row than the one it prompted for. The caret blinks, so a shot may miss it. |
| OCI list with eight profiles keeps its column header | The mock's flex rows pushed the header out; Win98 list views keep it. |
| The flat 63-app Programs list shows Win98 icons for known apps | The mock used the document icon for all of them. |
| Notifications: a third card that overflows gets a scroll bar | The mock clipped it with no bar; a scroll region must show that more exists. |
| Elision points in long titles differ by a glyph or two | Qt and Chrome cut at different characters before the three dots. |
| The focused card shows the focus rectangle on the button Enter runs | The mock drew it on the first card's first button only. |

### Not verified

- Nothing ran on Myoko or under the real Hyprland. Layer surfaces were counted with niri, not `hyprctl`: a nested Hyprland stalled waiting for the parent's dmabuf feedback under labwc and failed on an `xdg_wm_base` version under sway. `HyprlandFocusGrab` does nothing under sway; the menus there rely on exclusive keyboard focus and the full-screen press catcher, which Hyprland also honours.
- The Ctrl+Esc bind: its Lua (the theme-name reader) was run under Lua 5.4 and `luac -p` passes on the whole file; Hyprland's Lua was shown to provide `io` in a nested test, but the bind itself was not pressed in a running Hyprland.
- Urgency: wired to `HyprlandToplevel.urgent`; no real window asked for attention.
- Two outputs were checked at scales 1.5 and 1 only; a fractional scale such as 1.25 gives a unit that is not a whole pixel count and was not drawn.
- Motion: the Start roll-out (120 ms) and its reduced-motion form are checked by `checks.win98-theme` on the library; no recorded take of the Desktop was made, and nothing in the session publishes reduced motion.
- Drag and drop between window buttons was drawn (the `tb-drag` state) and `dropOnto` is the shell's; a real drag was not performed in the behaviour test.
- The captures and the checks use llvmpipe, not Myoko's GPU.


## Phase 3: Platinum Apple menu, Application menu and Control Strip (implemented)

Spec: the approved mock at `/tmp/strip-mock/` (`REPORT.md`, `shots/`; the 8.5 tear-off palette was dropped and is not built). Built inside the phase 1 contract: flat `Platinum*` files, `PlatinumTokens`, `context.shell`, the shared `MenuState`, the `chrome` IPC.

### What was built

| Part | Files |
|---|---|
| Cascading Platinum menus drawn from rows | `PlatinumCascadeMenu.qml`; rows from `themes/platinum/menu-models.js` (+ `.test.js`) |
| Apple menu on the mountain | `PlatinumTopBar.qml` (the mark is the `apple` title), `PlatinumDesktop.qml` (`appleRows`, `perform`) |
| About, confirmation alerts | `PlatinumDialogFrame.qml`, `PlatinumAboutWindow.qml`, `PlatinumAlert.qml` |
| Application menu at the right end | `PlatinumTopBar.qml` (the `app` title, on the bar or in »), `PlatinumDesktop.qml` (`applicationRows`, cycling) |
| Hide / Show for every theme | `WindowHider.qml` (one owner at the shell root), `window-hide.js` (+ `.test.js`) |
| Running apps, MRU, Super+Tab order | `app-model.js` (+ `.test.js`); `shell.qml` (`windowRows`, `mru`, `chrome cycle`) |
| Control Strip | `PlatinumControlStrip.qml`, `PlatinumStripTile.qml`, `PlatinumAppIcon.qml` + `PlatinumStipple.qml` (the disabled stipple), `themes/platinum/strip-plan.js` (+ `.test.js`) |
| Super+Tab held | `modules/hyprland/hyprland.lua` |
| Picker below the bar | `PlatinumPickerView.qml` (anchored at the left under the bar, not centred) |
| Check | `checks.platinum-desktop` (the four policy tests); `bar-delivery` asserts the new files are delivered and their tests are not |

The contract grows, it does not change: `context.shell` gains `windowRows`, `mru`, `hider`, `rowOf`, `activate`, `closeWindow`, `moveToPage` and `pageIds`; the `chrome` target gains `cycle <step|commit|cancel> <position> <seq>`; `chrome open` accepts `apple` and `app` (focused screen). A Desktop without `cycle()` (Win98) ignores the cycle messages. The strip keeps the default layer namespace, so `theme-dev/win98/switch.sh` still counts Platinum's two `quickshell` surfaces.

Early `chrome open` calls wait for an active Desktop of the requested theme.
The shell keeps only the latest request per captured screen. It drains the
request on the next event-loop turn after registration, not inside the Loader's
activation callback. A theme change drops pending requests; an old Desktop
cannot consume a request for its replacement. Cost: rapid opens before readiness
coalesce, and an open during a theme change can be dropped.

### Decisions made without asking

| Decision | Reason / cost |
|---|---|
| **Window order inside a page: screen position** (x, then y, from `lastIpcObject.at`), the compositor's order when a position is unknown | Evidence, nested Hyprland 0.56.2: after `window.swap` the socket sent only `activewindow`/`activewindowv2`, and the strip kept the old order because `lastIpcObject` is only rewritten by a refresh (`/tmp/platinum-menus/evidence/order-0-after-swap-stale-positions-x2.png`). The shell now refreshes toplevels 150 ms after `closewindow`, `activewindowv2`, `changefloatingmode`, `fullscreen` and after its own swap/move; after a strip swap and after `layout swapwithmaster` the tiles follow the windows (`order-1-…`, `order-2-…`). The shared `lanes.js windowsOn` (Win98's taskbar) is unchanged. Cost: a layout change with no event and no focus change stays stale until the next one. |
| **Super+Tab:** a quick press is still `focus { last = true }`; a held Super with more Tabs cycles apps in MRU order on the Application menu; Super up commits | `hl.is_key_down("Super_L")` reports the held key (`SUPER_L` and keycodes do not). A 25 ms repeat timer in Lua watches it, instead of a release bind on Super_L that would fire after every Super chord. Each message carries the position and a rising number (`os.time()*1000+n`), so out-of-order `qs` processes cannot undo a commit. Shift+Tab steps back; Escape mid-cycle cancels and the release then commits nothing; a lost release ends the cycle after 60 s. Evidence: 30 of 30 held trials (2–4 Tabs, 20–270 ms gaps, release 5–120 ms after the last Tab) closed the menu and switched to the highlighted app (`/tmp/platinum-menus/logs/cycle-trials.log`). |
| The cycle order starts after the app the quick press reached | The first Tab already focused the last window, so position 2 is the next app after it in the pre-press order (the MRU with its two first windows swapped back). Hidden apps take part; choosing one shows it. |
| Hide: per-app special workspace `special:hidden-<app id>`, `follow = false`; home pages in `$XDG_STATE_HOME/mountainous/hidden-windows.json` keyed by window address | Survives a Quickshell restart (verified: hide two apps, kill Quickshell, start it, Show All returns both to pages 1 and 3). A window found hidden with no entry goes to the screen's shown page. Show returns a window to its page, not to its old layout slot. |
| Hide Others is this screen only; Hide <app> and Show All act on every screen | The brief fixed Hide Others; Hide <app> means the app, and Show All undoes any hide. |
| The Application menu stays reachable | With no front app (everything hidden) it shows the desktop mark alone, so Show All stays one click away at ordinary widths. Below the old 191 px floor, it can move into » after battery and clock; Show All remains available there. |
| A window submenu lists windows in page order, each with its page; another screen's window adds the screen's name | As the mock. Choosing an app activates its most recent window (MRU). |
| Every menu action runs on the next turn of the event loop, after the menu closes | The menu is destroyed while its signal is on the stack; acting in that call lost Control Panels ▸ Appearance… and logged `QQmlVMEMetaObject … invalid context`. The alerts clear their state last for the same reason. |
| All panels of a cascading menu live in one window-sized item | With the cascade outside its parent item's bounds, the first hover into a cascade was lost 8 times in 10 (warped pointer); inside, 34 of 38 probes lit the row at once. |
| Launches go through `Launcher` (`docs/decisions/desktop-safety.md`): a pinned web app runs `Launcher.launch(entry.command, {id: "webapp-<id>", name, icon, kind: "webapp"})` (`launchEntry` when the entry has no command); a Recent Applications row runs `Launcher.launch` with its recorded argv and metadata | Each app gets its own systemd scope, and Recent Applications reads `Launcher.recent`. This phase was built against a stub with the same API in the nested session; the stub fallback was removed when the branch landed on the real singleton. |
| Pinned web apps: desktop entries whose id starts `webapp-` | `modules/web-apps.nix` names them so; their lettermark icons come with them. |
| Remote builds under Control Panels only where `builderGate.enabled` | As the bar. Bluetooth, Brightness, Sound and Wi-Fi are always listed and open their own menu under their title, under » when overflowed, or top right when the hardware is absent (as `chrome open`). |
| Session commands | Lock `loginctl lock-session`, Sleep `systemctl suspend`, Log Out `hyprctl --instance 0 dispatch hl.dsp.exit()` (as Super+Shift+E and Win98), Restart `systemctl reboot`, Shut Down `systemctl poweroff`. |
| No polkit agent or rule is added for Sleep, Restart and Shut Down | Myoko's evaluated `security.polkit.extraConfig` has no `login1` rule, and Simon is in `wheel`. systemd's `org.freedesktop.login1.policy` (read on Zao's systemd, not Myoko's build) allows `reboot`, `power-off`, `suspend` and their `-multiple-sessions` forms for an active session (`allow_active yes`). Cost: an app holding a *block* inhibitor makes logind ask for `ignore-inhibit`, which needs an agent the session does not run; the command then fails and nothing happens. |
| About shows Host, NixOS (version, generation), Revision (`configurationRevision`, "Not recorded" when unset), Uptime, and the DMI product name under the title | The brief's fields; the product name is what the mock showed. |
| Strip surface is taller (42 + 52 px) than its 42 px exclusive zone; input only on the strip | The drag label and ghost draw above the tiles. Collapsing never changes the zone. |
| Move to page from a tile is silent (`follow = false`); a drag across pages keeps today's `dropOnto` | The menu row says where the window goes; the user stays where they are. |
| Tile menu: right-click or the ▴ corner (13 × 15 hit area) | As the mock. |
| Stipple: icon through `MultiEffect` (saturation −1, contrast −0.25) under a one-physical-pixel checker of the surface colour masked to the icon | Qt's SVG renderer has no `<pattern>`, so the checker is one path of unit squares at the icon's physical size. |

### Narrow and short bar follow-ups

The planner no longer returns a clipped layout below its old 191 px floor.
After the normal controls and dictation actions overflow, padding reaches zero.
Battery, clock and Application then move into » in that order. Clock clearance
and outer edges yield last. The full mountain and » fit down to 36 px. Below
36 px, Apple menu is the first row in », including its Find… row. Below 16 px,
» itself shrinks to the container width. A zero-width container cannot present
a control. Cost: more menu depth at tiny widths; the battery is a read-only row.

The overflow menu uses `PlatinumMenuList` and `PlatinumScrollBar`. Selection
brings each row into view. The real-QML probe visits all rows at `maxHeight`
60, 130 and 600. The planner sweep checks every width from 1 to 400 px.
`bar-model` runs both tests; `bar-delivery` requires their passing result.
Cost: short menus scroll instead of showing the whole list at once.

### Evidence

Nested Hyprland 0.56.2 (Lua config with the shipped Super+Tab block cut from this file), headless labwc, 2880×1800 at 1.5, no seat, no DRM, no libinput (`LIBSEAT_BACKEND=seatd`, a missing `SEATD_SOCK` and `AQ_DRM_DEVICES`; the harness refuses to continue if the log shows otherwise). Stand-in apps are foot windows with the mock's app ids and icons. A persistent virtual keyboard with a full US keymap drives Super+Tab (wtype's per-run keymap fired no Hyprland bind). Session commands ran against logging stubs; nothing was suspended, rebooted, powered off or logged out.

Shots (`/tmp/platinum-menus/shots/`, light, grey, black): rest, collapsed, tile menu with Move to page ▸, Application menu with GitHub's windows, Apple menu, Control Panels ▸, Recent Applications ▸, the hover sweep Apple → clock → Application, Super+Tab, drag to page 3 and its result, a same-page swap and its result, About, the three alerts, Appearance…, Hide Firefox then Show All, resized short and scrolled, Find…, Control Panels ▸ Bluetooth, 300 % zooms; 600 and 360 px wide; Win98 and back. Side-by-side with the mock: `/tmp/platinum-menus/compare/`. Logs: `/tmp/platinum-menus/logs/`.

Theme swap with the Apple menu and a cascade open, three rounds: Platinum maps `mountainous-bar-shadow` + two `quickshell` surfaces and reserves top 28 / bottom 42; Win98 maps `mountainous-taskbar` and reserves bottom 38; no menu surface survives a swap; one Quickshell process.

### Not verified

- Nothing ran on Myoko or under its GPU, Kanata or real keyboard. Super release was read from a virtual keyboard; Kanata's uinput device is a real libinput keyboard, which `is_key_down` should see the same way (inferred).
- Two screens: Hide Others per screen and the per-screen strip state are covered by the unit tests only.
- Hover into a cascade by a warped pointer still missed 4 of 38 probes; a real pointer sends continuous motion (inferred to be unaffected).
- With the pointer resting on a bar title, a menu opened by keyboard from a cascade can hand over to that title's menu (the sticky hover sees the bar re-entered).
- Strip keyboard focus: the strip, like the dock, has no keyboard path; its windows are reachable from the Application menu and the omni bar.
- The nested session ran against a `Launcher` stub. The landed code calls the real singleton; its launches into scopes were proven in the desktop-safety work, not in this phase's session.
- `configurationRevision` was not set on the evaluating host, so About showed "Not recorded".



## Fleet window and glance space, Windows 98 (implemented)

Spec: the approved Win98 mock pass 2 at `/tmp/win98-hud-mock/` (`REPORT.md`, `DIRECTION.md`, `shots/`), with Simon's three defaults accepted: the checker cell is one Win98 pixel (2 device px, `Win98Dither`); details open in a Properties sheet beside the Fleet window (over it when there is no room); a click on the Glance button opens its menu and a double-click hides the space. The data, its rules and the glance layout are the shared ones (`beszel-model.js`, `panels/Beszel.qml`, `glance-plan.js`, `glance-registry.js`, `GlanceState`); only the views are Win98's.

### What was built

| Part | Files |
|---|---|
| One screen's Fleet views (the controller: window shown, minimized, Details or Large Icons, the sheet's tab) | `Win98FleetGlance.qml` |
| The Fleet body for both hosts: View menu bar, Details with clickable headers and block bars, Large Icons with overlays and Resource Meter bars, the status bar, the View and control menus, row tooltips | `Win98FleetView.qml` |
| The standalone window above the tray, its sheet, minimize to the taskbar | `Win98FleetWindow.qml` (layer `mountainous-fleet`) |
| The Properties sheet: General, Performance, Services, Disks; tabs in one row that scroll with an up-down control | `Win98FleetProperties.qml`, `Win98Tabs.qml` (`singleRow`) |
| The glance space: the Shut Down checker, Fleet and Disks from the bottom right, the caption animation | `Win98GlanceSpace.qml` (layer `mountainous-glance`), `Win98DisksAccessory.qml` |
| New controls | `Win98HeaderView.qml`, `Win98LevelBar.qml` (`blocks`, `vertical`), `Win98HostIcon.qml`, `Win98SysmonChart.qml`, `Win98PieChart.qml`, `Win98MenuBar.qml`; `Win98Window` (minimize button, caption icon item and press); `Win98MenuPanel` (bold default item, radio dot); icons `glance.svg`, `minimize.svg`; chart, meter and pie colours in `Win98Tokens` |
| Taskbar and tray | `Win98Taskbar.qml` (the tray Fleet icon; an extras band with the pressed Glance button and a minimized Fleet's button), `Win98MenuHost.qml` (the Glance menu, the Fleet icon's menu), `Win98Desktop.qml` (`toggleFleet`, `toggleGlance`, `showGlance`, `hideGlance`, `fleetShown`, `fleetDetailShown`) |
| Pure policies and tests | `themes/win98/fleet-plan.js` (the width levels, the height order, Large Icons, the standalone place, the sheet's place, the caption timing), `tab-strip.js`, `host-icon.js`, `taskbar-plan.js` (extras; `fleet` after `disk` in the overflow order), `tray-model.js` (`fleet`: label, chord F, tooltip); `fleet-plan.test.js`, `taskbar-plan.test.js`; `glance-plan.js` gains `opt.gp` and `opt.from: "bottom"` (Platinum's calls are unchanged) |
| Harness and checks | `theme-dev/win98/`: `beszel-stub.js` and `fleet-fixtures.json` (the mock's fixtures behind the real Beszel owner), `fleet.sh`, `capture-fleet.sh`, `switch.sh` (a Fleet view open before every swap), `session.sh` (`SESSION_SCALE`, and `session_stop` stops every process of the session), `pointer.py` (right click, wheel); `checks.win98-fleet`; `checks.win98-desktop` runs the new pure tests; `bar-delivery` asserts the new files |

Keys and routes: Super+B and Super+O F (`fleet toggle`) toggle the window, bring a minimized one back, and from the glance space go back to the work with the window open. Super+W (`glance toggle`, `reveal`, `hide`) toggles the space. A click on the tray Fleet icon toggles the window; its right button opens Open Fleet (bold, Win+B) and Show Glance (Win+W). `chrome open fleet` toggles the window too. Beszel polls while the tray icon shows, as it does while Platinum's bar readout shows.

### Decisions made without asking

| Decision | Reason / cost |
|---|---|
| Notepad and Date/Time are not built | `glance-registry.js` lists Fleet and Disks only, so Platinum has no such accessories; the mock drew them as placeholders. The registry adds them for both themes later. |
| The Disks accessory shows StorageHealth's findings, not a drive pie | Platinum's Disks widget shows the findings; the mock's pie had no data source (it was a placeholder). The pies are in the Properties sheet's Disks tab, from Beszel's filesystem percentages. |
| No adapter for the SMART and service shapes in `beszel-model.js` | `beszel-status host` already reduces `list_services` to names and passes `list_smart_devices`' real fields (`smartState`, `capacityGb`); the views read those, as Platinum's do. |
| Remembered places stay `{r, t}` in logical px in the shared `glance.json` | One file for both themes; a place dragged under Win98 is the same top-right margin under Platinum. Only Clean Up order is mirrored. Cost: a remembered place is measured from the top, not from the taskbar. |
| The standalone window is not draggable or resizable, and ignores Platinum's saved window place | The brief places it above the tray; Platinum's `fleet {r, t, w, h}` would put it at the top right. Cost: one place only; the glance space's accessories do drag. |
| `checks.win98-fleet` is its own attribute | `fleet.sh` takes 3 to 12 minutes here; with the existing `win98-desktop` scripts one build could pass the 15-minute step. |
| The tray Fleet icon has no count badge | The overlay gives the tone and the tooltip names the problem hosts; the Platinum readout's count is in the tooltip and the summary. |
| The space's front window draws the active caption whether or not the surface has the keyboard | Under Hyprland the focus grab gives it the keyboard; the caption no longer depends on it. |
| Uptime's column holds "seen 49m ago" only when a host is down (the mock's rule) | Platinum reserves it always; that made the Win98 window 40 u wider than the mock with every host up. |
| Column headers draw no sort mark; a second click on the sorted header goes back to name order | As the mock. |

### Evidence

Headless sway (pixman, no output device) in a bubblewrap namespace with no DRI node, Qt on llvmpipe (`/tmp/tandem/win98-fleet/sandbox.sh`, `env.sh`); the real `ThemeDesktop` and `Win98Desktop` over the production `Beszel` owner fed by `beszel-stub.js`. Evidence: `/tmp/tandem/win98-fleet/` (served at `http://100.114.19.92:8765/tandem/win98-fleet/`).

| Run | Result |
|---|---|
| `checks.win98-fleet`: `fleet.sh` (behaviour, the motion's held frames, 12 fixtures, bounds at 360x640, 800x480, 1280x800, 1920x1200 at 1.5 and the 2560x1600 tablet at 2) | 140 of 140 (`nix/win98-fleet.log`) |
| `checks.win98-desktop`: `switch.sh` with each theme's Fleet window or glance space open before each of the 20 swaps | 147 of 147: the old view is mapped before the swap, and after it only the new theme's surfaces are (no `mountainous-fleet` or `mountainous-glance` survives); `GlanceState` names no screen (`nix/win98-desktop.log`) |
| `checks.win98-desktop`: `behaviour.sh`, `geometry.sh`, `scales.sh` with the Fleet tray icon; the pure tests | 33 of 33, 50 of 50, pass; `fleet-plan.test.js` and `taskbar-plan.test.js` pass |
| `checks.win98-theme`, `fleet-glance-model`, `desktop-theme-shell`, `bar-delivery`; the Myoko toplevel `drvPath` | pass; evaluates (`nix/summary-1.txt`, `nix/myoko-toplevel.log`) |
| The checker | A 200 x 200 device-px crop of the light space over the teal desktop: 20,000 black pixels and 20,000 of the desktop's own colour, nothing else (`compare/dither-histogram-light.txt`) |
| Motion | Held frames 0 to 10 of the summon and the dismiss: captions in flight in frames 0 to 8, the windows at frame 9, the dither gone at dismiss frame 9 (`compare/motion-filmstrip-{in,out}.png`); reduced motion is the cut |
| Screenshots | `shots/` (standalone and glance, light and dark grey, every fixture, each tab, Large Icons, minimized, the Glance menu, the empty space, remembered places, five sizes); the mock and the build side by side in `compare/` |
| Isolation | Every session ran in a bubblewrap namespace with no DRI node in `/dev`, after the first runs also in its own PID namespace; the fd scan of a live session is `proof/scan.txt` |

The build differs from the mock where the mock drew placeholders (Notepad, Date/Time, the Disks pie), where the shared model says more ("sdc failed SMART" leads unzen's reasons once its drill-down has run), and in the Glance menu's place (centred on its button, as the tray windows are).

### Not verified

- Nothing ran on Myoko, under Hyprland, or with a real keyboard and pointer. HyprlandFocusGrab does nothing under sway, so "a click outside dismisses the space" was checked as a click on the space's own background, and the window's on-demand focus (no keyboard until clicked) was not checked: sway focuses an on-demand layer surface when it maps.
- Layer stacking under Hyprland: the menu host and the glance space are both Top-layer surfaces; the Glance menu over the space was seen under sway only.
- Real Beszel data: every run used the mock's fixtures.
- The 1.25 scale, two screens, and the dither on Myoko's OLED.

## Find menu: Platinum's Super+P (implemented)

Spec: the approved option B at `/tmp/find-mock/` (`REPORT.md`, `INVESTIGATION.md`, `DIRECTION.md`, `shots/*-B-*`). Super+P, F1 and Apple menu ▸ Find… drop a 400 px Platinum menu from the mountain on the focused screen, with no veil and no motion. Its first item is a scope pop-up ("All ⇕") and a sunken field with the lavender focus ring; the rows filter live, grouped under Windows (by screen), Applications and Commands. Ctrl+L and the "Go to address" rows open Go to Address, a Platinum dialog under the front window's title that navigates through `CdpBrowser`.

### What was built

| Part | Files |
|---|---|
| Rows, ranking, scopes, entry rules (pure) | `find-model.js` (+ `find-model.test.js`), shared and theme-neutral |
| Menu and dialog sizes (pure) | `themes/platinum/find-plan.js` (+ `.test.js`) |
| The Find menu | `PlatinumFindMenu.qml`: field row, scope pop-up, grouped rows, ▲/▼ arrow bands, Balloon Help |
| Go to Address | `PlatinumGoToAddress.qml` on `PlatinumDialogFrame` and `PlatinumButton` |
| The field | `PlatinumTextField.qml`: sunken well, black inner edge, lavender ring (`PlatinumTokens.focusRing`) |
| Wiring | `PlatinumDesktop.qml` (menus `find` and `address` in `menuMap`, the service sync), `PlatinumTopBar.qml` (the mountain open for `find`, the title underlined and the dialog's anchor for `address`), `PlatinumMenuHost.qml` (`placeX`, `topGap`), `PlatinumBarControl.qml` (hover over the bar does not take over from `find` or `address`) |
| The service | `OmniBar.qml`: `enter*` through `FindModel.enter`, `screen`, `claimView`/`releaseView`, `navigateTo`, the `cmd` mode, `run({kind: "recent"})` |
| Launch kind | `launcher-model.js` `entryKind`, used by `Launcher.launchEntry` |
| Check | `checks.find-menu`; `bar-delivery` asserts the new files are delivered and their tests are not |

### The contract grows

The omni service stays one shared owner (`shell.qml`, `context.omniBar`), with its IPC target `omni` (`toggle`, `reveal`, `gotowindow`, `apps`, `navigate`, `dismiss`) and its public rows (`windowRows`, `appRows`, `commandRows`) and `run(row)`. New: `mode` may be `cmd`; `screen` is the focused screen captured on the way in; `enterMode(mode, text?)` and `enterNavigate(text?)`; `back()`, `dismiss()`, `navigateTo(text)`; `claimView(owner)` and `releaseView(owner)` with `themed`. A Desktop that draws its own view claims it while active; the unthemed card shows only while nothing claims it. Win98 claims it too since its Find window and Open dialog landed (see "Find window, Open and web pages for Win98" below); `checks.theme-parity` now fails if either theme stops claiming it. `omni apps` now opens the Applications scope (it opened All, and the `app` mode was unreachable).

### Decisions made without asking

| Decision | Reason / cost |
|---|---|
| **The old card stays in `OmniBar.qml`**, as the service's unthemed default view, shown when no active Desktop claims the view | The contract keeps the omni bar unthemed and shared by every theme. Win98 uses it unchanged, and any later theme without its own view still has a working Super+P. Moving it into a `Win98*` file would make Win98 own a shared view and would leave a third theme with no Super+P. Cost: `OmniBar.qml` holds both the service and one view. |
| The caller is captured on every entry point, in `FindModel.enter`, from `Hyprland.activeToplevel` or the last window that held it | Bug 1 of the investigation: only Ctrl+L captured it, so "Go to address" from Super+P could target a stale window. A layer surface (the Apple menu) can hold the keyboard when Find… runs, so the last active window is the fallback. "Close window" now closes the caller too. |
| Find and Go to Address are bar menus in `MenuState` (`find`, `address`) | One menu at a time, a click outside closes, Esc goes through the host. The Desktop syncs the service and MenuState on the next turn of the event loop (a binding here was read again inside its own change and closed the service). |
| Esc and Backspace on an empty field leave the scope, then close; a held Backspace stops at the empty field | The brief; the auto-repeat guard keeps a held Backspace that clears the text from closing the menu. |
| Esc in Go to Address cancels and closes; Backspace on its empty field goes back to the Find menu | The brief and the Mac rule; Backspace keeps today's way back. |
| Hover moves the highlight only after the pointer really moves | A pointer resting where the menu opens would otherwise take the highlight and break "Super+P, Return". |
| Balloon Help: 600 ms on a cut-off row, beside the menu, or over the rows under it when the screen has under 180 px to the right | The full title stays reachable at 360 px. |
| The hint column is a readout: 45% of the row, 38% under 300 px, hidden under 250 px; the scope pop-up becomes a "Windows:" label under 260 px | `find-plan.js`; every threshold is a guess until measured on Myoko. |
| A host typed alone offers "Go to “host”" with no rule above it | The mock drew an empty rule there. |

### Evidence

Nested Hyprland 0.56.2 under headless labwc, 2880×1800 at 1.5 with a second output "SUNSHINE", light, dark grey and extra dark. labwc and Hyprland ran in a bubblewrap namespace whose `/dev` held only `/dev/dri/renderD128`; Chromium ran in one with no `/dev/dri` at all and `--disable-gpu`. Evidence and logs: `/tmp/find-build/` (served at `http://100.114.19.92:8765/find-build/`).

### Not verified

- Nothing ran on Myoko, under its GPU, Kanata or a real keyboard. Keys came from a virtual keyboard through the real Hyprland binds.
- Ctrl+L inside the Find menu with a non-browser front window: Hyprland's Ctrl+L bind passes the key to that window, so the menu does not see it. The scope pop-up's "Go to Address…" and the "Go to address" rows still open the dialog.
- Keys typed in the moment between Super+P and the menu's surface mapping go to the window behind (inferred to be as before).

## Find window, Open and web pages for Win98 (implemented)

Spec: the approved parity mock at `/tmp/tandem/win98-parity-mock/` (`REPORT.md`, every default approved; items 2 and 10; `DIRECTION.md`). Super+P, F1, Start ▸ Find ▸ <scope> and Start ▸ Run… open Win98's Find window above the Start button; Ctrl+L, Look in ▸ Go to Address…, Start ▸ Find ▸ Address… and the Find window's "Go to" rows open Internet Explorer's Open dialog, centred on the window it acts on. Web pages get `themes/win98/web.css`. Both are views of the shared omni service; nothing in `OmniBar.qml`, `find-model.js` or `CdpBrowser` changed.

### What was built

| Part | Files |
|---|---|
| Find window | `Win98FindWindow.qml`: Named field, Look in (All, Applications, Windows, Commands, Go to Address…), Open and Close, the Details list with Platinum's groups as rows (bold on the face colour, an etched rule), a status bar (count, the chosen row's kind and details), an in-place tip for a cut name |
| Open dialog | `Win98OpenDialog.qml`: the globe and its line, "Open:" with an editable combo (the address prefilled and selected, the open pages in its drop-down, filtered as you type), where OK opens it, OK and Cancel |
| Claim and wiring | `Win98OmniView.qml` (claim while active, release when inactive or destroyed, the service ↔ `MenuState` sync, running a row), ten lines in `Win98Desktop.qml`, the `find`/`address` entries and their placement in `Win98MenuHost.qml` |
| Sizes (pure) | `themes/win98/find-plan.js` (+ `.test.js`): `findPlan`, `openPlan`, `dropPlan`, row arithmetic |
| Start | `themes/win98/start-model.js`: Start ▸ Find ▸ All…, Applications…, Windows…, Commands…, Address…; Run… opens Find in All |
| Controls | `Win98TextField.qml` gains `keyPressed` (the list keys) and `rightInsetUnits` (a combo's button); `Win98Text.qml` exposes `drawnText`, `accessX`, `accessWidth`; icons `find`, `find-large`, `globe`, `globe-large` |
| Web pages | `themes/win98/web.css`: Platinum's sections, guards and rules, Win98's scroll bars and controls, W95FA on buttons, drop-down lists and legends only |
| Checks | `checks.win98-desktop` runs `find-plan.test.js` and `theme-dev/win98/find.sh` (behaviour and geometry, real keys and pointer); `checks.win98-theme` runs `dev/access.sh`; `checks.web-theme` lints win98; `checks.theme-parity` (new); `bar-delivery` asserts the new files |

### Keys

As `find-model.js` and Platinum's menu: typing filters; Up/Down/PageUp/PageDown move; Enter, Open, or a double click runs the row; Ctrl+1/2/3 pick a scope; Ctrl+L opens Open; Alt+Down or F4 opens Look in (Up/Down/Enter/Esc inside it); Alt+N, Alt+L, Alt+O. Esc and Backspace on an empty field leave the scope, then close; a held Backspace stops at the empty field. In Open: Enter is OK; Down or F4 opens the list; Esc closes the list, then the dialog; Backspace on an empty field (a new press) goes back to Find.

### Decisions made without asking

| Decision | Reason / cost |
|---|---|
| Find and Open are `MenuState` entries (`find`, `address`) in the Win98 menu host, as Platinum's are in its host | One menu or window at a time, a click outside closes, and the host's full-screen surface already has the keyboard and the press-catcher. Cost: a click outside closes Find, which a Win98 dialog did not do. |
| The claim lives in `Win98OmniView.qml`, not in `Win98Desktop.qml` | Other workers edit the Desktop too; ten added lines rebase more easily than a hundred. |
| A pointer resting on a taskbar control does not take over from Find or Open | As Platinum's bar; the hover hand-over is for menus. |
| Window rows use the Win98 icon set where the taskbar does (`start-model.js appIcon`), else the icon theme, else the document icon | One icon per app across the taskbar, Start and Find. Cost: a Chromium web app shows Chromium's icon, not its lettermark (as on its taskbar button). |
| The Find window's body scrolls as a whole when even three rows do not fit (under about 160 u of room) | Phase 2's rule for every Win98 window: the buttons scroll with the body, Enter and Esc work wherever they are. The mock pinned them; the case starts far below 360x640. |
| Open's drop-down opens as you type, and a click on a page goes there at once | IE5's AutoComplete; as the mock. |
| Open names the caller's app from its desktop entry itself | The Desktop has no `appName()`; the dialog does not need one. |
| `web.css` token names are `--mtn-*`, with two new ones: `--mtn-well-edge-low` (a well's light outer edge) and `--mtn-focus` dark = `#8e8e8e` | The lint is shared; a Win98 well has two outer colours, and the dotted focus box outside a check box sits on the page, which may be white in dark mode. |
| W95FA stays off list boxes (`select[multiple]`, `[size]`) | The brief says drop-down lists; a list box is a well of typed data, like a field. |
| No new site opt-outs | Nothing found broke on the stress page; live sites were not tried (see Not verified). The YouTube Music skip is shared and applies to Win98 too. |
| The parity check finds the contract in `shell.qml` itself | A new routed method (`desktop.X()`, `typeof desktop.X`, `fleetCall`, `anyDesktop`) is covered without editing the check. Cost: a feature routed some other way needs a line in the check. Chrome control IDs (`chrome open <id>`) are not compared. |
| A closed gap fails the check until its ledger line goes | Keeps the ledger true. Cost: when Fleet/Glance or Alt+Tab lands for Win98, that branch (or the rebase of this one) must delete the matching lines. |

### Evidence

Headless, as phase 2: the real QML in sway's headless backend (pixman), Qt on llvmpipe, private runtime, state and config directories, the harness's data owners and `OmniFixture.qml` (the omni service's public shape with the real `find-model.js` entry rules). By hand, every session ran in a bubblewrap namespace whose `/dev` held only `/dev/dri/renderD128`, with `LIBGL_ALWAYS_SOFTWARE=1` and nonexistent `SEATD_SOCK`, `AQ_DRM_DEVICES` and `WLR_DRM_DEVICES`; Chromium ran in one with no `/dev/dri` and `--disable-gpu`. The live session was not touched. Evidence: `/tmp/tandem/win98-find-web/` (http://100.114.19.92:8765/tandem/win98-find-web/).

| Gate | Result | Evidence |
|---|---|---|
| `find.sh` (in `checks.win98-desktop`) | 102 of 102: 41 behaviour checks (claim, Super+P, typing, Up/Down, Ctrl+1/2/3, Look in by keys and pointer, Esc and Backspace rules, a held Backspace, Enter, Open, a double click, Close, a click outside, Ctrl+L, Open's prefill, list, Esc order and navigation, Backspace back to Find, Start ▸ Find ▸ Windows…, Start ▸ Run…, the release on a swap to Platinum and back) and 61 bounds checks at 1920x1200, 1280x360, 1280x300 (one criteria row in a 520 u window), 640x360, 360x640 and 360x800 | `logs/find4.log` |
| The plans | `find-plan.test.js`: every threshold one unit either side, the height ladder from 431 u down to 40 u (steps only grow, whole rows, at least three) | `checks.win98-desktop` |
| Access keys | 7 labels: the drawn run keeps its spaces and their advance; the underline starts after them | `checks.win98-theme` |
| Web pages | The mock's stress page under no theme, Platinum's and Win98's real sheets, light and dark, 2880x1800 at 1.5, and 360x640; the Win98 column matches the approved draft except list boxes, which keep the site's font | `shots/web/` |
| Beside the mock | 11 Find and Open states x light and dark grey x the mock's 1920x1200, 1280x360 and 360x800: whole screens and window crops side by side | `compare/` (`summary.tsv`) |
| No GPU, no seat | Every session: 0 `/dev/dri/card*` open in an fd scan of the namespace, 0 DRM or seat lines in sway's log | `shots/*/drm-proof.txt` |

### Where the build differs from the mock

| Difference | Why |
|---|---|
| The desktop colour behind the windows | The mock painted app windows; the harness shows the Win98 desktop. Most of each crop's differing pixels (11% on average; 7% in dark grey) are this. |
| A Chromium web app's row shows Chromium's icon | As its taskbar button (`start-model.js appIcon`); the mock drew site lettermarks. Web apps without a theme icon fall back to the document icon. |
| 28 items, "Go to window", "Go to address" | The harness lists `OmniBar.commandRows` as written; the mock used its own shorter list. |
| Names elide a glyph or two later or earlier | Qt and Chrome cut at different characters. |
| The criteria rows are as tall as the buttons beside them (23 u) | The mock's plan counted 21 u rows and its render drew 23 u ones; the plan now counts what is drawn (the window is 4 u taller). |
| On a short, wide screen the window widens to 520 u to put Named, Look in, Open and Close on one row | The mock's one-row step kept Open and Close stacked beside a 21 u row, so it saved nothing; spending width is what the step is for. |
| Open's "new window" line takes two lines when it is long | The mock's line was one line; a long app name was cut. |
| A cut name's tip sits under its row and breaks into lines inside the screen | The mock's tip ran off a 360 px screen, so the end of the name was still unreadable there. |

### Not verified

- Nothing ran on Myoko, under Hyprland, with its GPU, Kanata or a real keyboard. Keys came from a virtual keyboard into sway; `HyprlandFocusGrab` does nothing under sway. The Hyprland binds (Super+P, F1, Ctrl+L on a `chrome-*` window) are unchanged and were not pressed.
- The omni service was the harness's stand-in, not `OmniBar.qml`: windows, apps, recent launches and pages were fixtures. A real navigation through `CdpBrowser` and a real launch were not run.
- `web.css` was applied to one local stress page, not to live sites (GitHub, Wikipedia, YouTube Music). A site whose buttons have a fixed height may clip W95FA's 16.67 px words; no opt-out was added for that, since none was seen.
- Scales other than 1.5 for the Find window (the plan is in units, so 1 and 2 follow by construction); `web.css` names 1 to 3 dppx; other ratios fall back to 1 px.
- Two screens: the Windows scope's groups by screen were drawn from fixture rows, not from a second output.

## Quiet glyphs: the Platinum top bar, direction A (implemented)

Spec: the approved mock at `/tmp/bar-calm/` (`REPORT.md`, `plans.js`, `shots/*-A-*`). Simon: "This is feeling a little crowded. We need to think about overflow and also just in general, like show, don't tell." Same items in the same places; the icons carry the values. Win98 is unchanged: it has its own taskbar, and no Win98 file or shared Win98 dependency changed.

### What changed on the bar

| Item | Before | Now |
|---|---|---|
| Sound | speaker + "35" | speaker with 0–3 lit waves (33/66 % steps); a slash when muted |
| Brightness | sun + "15" | sun with one lit ray per 12.5 % (at least one) |
| Battery | icon + "100%" | the fill; the percent comes back at 20 % or less on battery (battery.js warning/danger) |
| OCI egress | cloud + "fuji:1.8% yari:2.8%" | the cloud and one meter for the worst profile; "yari:84.0%" comes back while a profile warns (≥ 50 %) |
| Remote builds | hammer + "On by you" | the hammer (struck through while refusing, grey when the rule refuses), a dot while builds run; the words only while an action failed |
| Notifications | bell + "35" | the bell with a dot; the count only while urgent (danger) or sync fails (warning); offline keeps its "!" |
| Disks | disk + "ok" | the disk alone while healthy; "1 issue" (or "!", "stale") in its tone |
| Bluetooth | rune + "1" | the rune alone; grey while on with nothing connected, struck through while off |
| Wi-Fi | bars | the bars; on with no network adds "!" in the warning tone (it never yields) |
| Fleet | light + count | unchanged |
| Clock | "10/26  5:06" | "5:06"; the date is in the clock menu's header and in Balloon Help |
| Application menu | icon + name | the icon alone when the window title already names the app ("Forgerie" once) |
| » | grey | takes the worst tone of what moved into it |

Exact values stay in each menu's header and in **Balloon Help**, new: rest the pointer 600 ms on a title and a balloon under it gives the full value as a sentence ("OCI egress this month: fuji 1.8%, yari 2.8%. Click for usage in GB."). A volume or brightness change shows a **tag** under its control (under » when it overflowed) for 1.5 s: the icon, a level well and the number. Each value arms 2 s after its owner has one, so the values loaded at start raise no tag; a menu open on that screen suppresses it (the menu shows the value).

### Files

| Part | Files |
|---|---|
| The policy | `bar-plan.js`: the mock's `plan` ported (A's yield order, » order, dictation's group, the compact rungs), plus `place()`, `tagPlan()` and `balloonPlan()`; `bar-plan.test.js`, `bar-compact.test.js`, `bar-fixtures.json` (the widths the real bar measured for the mock's states) |
| The bar | `PlatinumTopBar.qml` (glyphs, readouts, chord placement, hover and tag state), `PlatinumBuilderControl.qml`, `PlatinumBarNumber.qml` (`byDigits`), `PlatinumMetrics.qml` (`digitBox`), `PlatinumBarBadge.qml` (the dot, shared by the bell and the hammer) |
| Balloon Help and the tag | `PlatinumBarHelp.qml`: a window of its own under the bar (namespace `mountainous-bar-help`, no exclusive zone, empty input mask), mapped only while it shows something; `PlatinumDesktop.qml` owns one per screen and exposes `bar` |
| Glyphs | `icons/speaker-0..3.svg`, `icons/brightness-1..8.svg`, `icons/cloud-meter.svg` in `PlatinumIconStore.qml`; straight edges on whole device pixels at 1.5, `currentColor`, so one file serves light, dark grey and extra dark. The meter's fill is drawn by the bar in whole device pixels (at least two once there is any use). |
| Super+O | `modules/hyprland/hyprland.lua`: N opens Notifications under Platinum (`desktop_theme_name()`); under Win98 the bind returns `ok = false`, so N passes through as before and Win98's chord letters are unchanged |
| Checks | `checks.bar-model` passes `PlatinumTopBar.qml` to the plan test (the chord placement); `bar-delivery` asserts the new files |

### The ladder (calm, as measured)

Spacing yields at 857 px, the clock leaves the centre at 679, the window title at 486, and the first control moves into » at 403 px (the mock: about 402). Then Disks 397, Fleet 371, Remote builds 349, Brightness 323, Bluetooth 297, Wi-Fi 271, Notifications 245, Sound 219; padding goes from 193; battery, clock and Application move into » below 144, 126 and 80 px; the Apple menu below 36. Nothing is lost from 191 px up. The yield order is `space, appName, diskLabel, uncentre, titleMin, builderLabel, ociNumber, ntfCount, fleetCount, batteryPct`: words go before the clock leaves the centre, and a warning number outlasts the window title. Every threshold is a guess until it is measured on Myoko.

### The two bugs the mock found

1. **Super+O covered the controls** (387–918 px today). The plan reserved the hint in the clock's place at the head of the right group once the clock is uncentred, but `PlatinumTopBar.qml` drew it centred. The plan now returns `chordPlace` and `chordWidth`; the right group holds a `chordSlot` of that width, and the chord stands there. `bar-plan.test.js` checks at every width that the placed chord covers no control (and that the old centred rule would have, at 495 widths between 363 and 858 px for the measured metrics), and that the QML takes its x from the slot.
2. **"1   issue"**: the count's box was sized for two wide digits. A warning number's box now holds its own digit count at the widest digit's width (`PlatinumMetrics.digitBox`), right-aligned before a word: "3" to "7" never moves, "9" to "10" grows by one digit, and "1 issue" has no gap.

### Decisions made without asking

| Decision | Reason / cost |
|---|---|
| Every item counts at its even drawn width in the plan (the mock counted raw widths) | What the plan fits is what the bar draws, so the placement test is exact. Thresholds move by a pixel or two from the mock's. |
| Disks shows "!" or "stale" in the warning tone when its check failed or is old | The mock showed the icon alone there; a warning state with no word would hide that the check is not running. They yield with the disk's words. |
| Notifications offline keeps "!" after the count yields | As before; offline is a sync failure, and the tone alone is easy to miss. |
| The tag shows on every screen's bar, and for a mute toggle ("--", speaker struck through) | The value is the machine's, not the screen's. Cost: two tags with two screens. |
| Balloon Help has no balloon for » or the mountain | » lists its items with values; the Apple menu has no value. |
| 191 px runs at scale 2 in the nested session | 191 logical px has no whole mode at 1.5 (286.5 px); Hyprland falls back to scale 1. 192 px at 1.5 stands beside it. |
| The » menu keeps a warning value's tone, names each OCI profile, shows each control's Super+O letter, and is as wide as its rows (260–400 px) | As the mock's » menu. Its rows still use the plain icons (no meter, no fleet light); the overflow-geometry probe is unchanged. |

### Evidence

Nested Hyprland 0.56.2 inside bubblewrap under headless labwc (only `/dev/dri/renderD128` in their `/dev`, `SEATD_SOCK` missing, `systemd-run` stubbed), the real staged Quickshell with a `barProbe` IPC target added to the staged `shell.qml` only. The probe feeds the mock's states into the production data owners; windows, focus, Super+O and the » keys are real (virtual keyboard and pointer through Hyprland's binds). Every session: 0 `drm: Starting backend` lines and 0 `/dev/dri/card*` in the fd scan. Evidence: `/tmp/bar-quiet/` (http://100.114.19.92:8765/bar-quiet/), with each build shot beside the mock's own render at the same width, state and look in `compare/`.

| Run | Result |
|---|---|
| light, every width (1920, 960, 640, 400, 320, 192 at 1.5; 191 at scale 2), calm, wrong, long, the volume tag, Super+O; every menu from its control and from »; Balloon Help; Super+O B W S L C D R N and F; Win98's N | 109 of 109 |
| dark grey, the same | 107 of 107 (first run); 106 of 107 on a rerun (one » keyboard step lost: Down arrows before the menu had the keyboard) |
| extra dark, the same | 107 of 107 |
| QML warnings from the changed files | 0 in every run (the only warnings are the session's missing services and `systemd-notify`) |

### Not verified

- Nothing ran on Myoko, its GPU, Kanata or a real keyboard. The volume tag came from a changed PipeWire stand-in, not a volume key.
- The data came from the probe, not from PipeWire, BlueZ, NetworkManager, UPower, OCI, the disk check or Beszel.
- 191 px at scale 1.5 (Hyprland has no such mode); one screen only, so the tag on two screens is not seen.
- Under Win98, Super+O N opens nothing (checked); whether the N then reaches the focused window, and whether the submap ends at once, was not checked.
- The thresholds and the glyph steps (waves at 33/66 %, rays per 12.5 %, the meter's two-pixel minimum) are guesses until Simon has used them.

## Window title bars (implemented)

Under Platinum every window that leaves its frame to the compositor gets a Mac OS 8 title bar and frame: a close box on the left; a zoom box and a collapse box on the right; pinstripes either side of a plain patch behind the ChicagoFLF title; a black edge and a one-hair bevel round the whole window. An inactive window's bar is flat, with a grey title and no boxes. The bars take the theme's appearance (light, dark grey, black) and follow `desktop-theme` live. Windows 98 is a second live style in the same plugin: navy (light) or steel (dark grey) or inactive grey gradient, W95FA Grid bold caption, minimize/maximize/close boxes and a raised square frame. Both appearances follow Win98Tokens. See the Win98 caption section below for the app-icon and menu integration boundary.

### What was built

| Part | Files |
|---|---|
| The plugin | `modules/hyprland/hyprbars-platinum.patch` on nixpkgs' hyprbars 0.56.0: `barDeco.cpp` (boxes, stripes, title colour by focus, the client-decoration test), `frameDeco.{hpp,cpp}` (the frame, a second decoration), `main.cpp` (config values, `hl.plugin.hyprbars.refresh()`, a redraw on focus change, `add_button` replaces a box with the same icon and side) |
| Packaging | `modules/hyprland.nix`: `packages.hyprbars-platinum`, `/etc/hypr/plugins/hyprbars-platinum.so`, the assertion that the session runs `pkgs.hyprland`, `titlebars.lua` delivered by Hjem |
| Styling | `modules/hyprland/titlebars.lua`: reads the three theme files, `settings(state)` (pure), `apply()`, `attach(opts)` from `hyprland.lua` |
| Following the theme | `modules/theme.nix`: every `desktop-theme` change runs `hyprctl eval '… require("titlebars").apply() …'` inside a Hyprland session |
| Collapse | `windows collapseActive` IPC in `shell.qml`, `WindowHider.hideWindow`, `window-hide.js hideWindow` |
| Checks | `checks.titlebars` (the patch builds; `titlebars.test.lua`: appearances, settings, attach, apply, and the palettes against `PlatinumTokens.qml`), `checks.desktop-theme` (the hook runs on every change and only then), `window-hide.test.js` (one window) |

### Decisions made without asking

| Decision | Reason / cost |
|---|---|
| The bars are drawn like the desktop's windoids (`PlatinumWindoid.qml`): a hair is `PlatinumTokens.hair` (2 device px at 1.5), boxes are an edge, a bevel and a face, stripes are light, dark, gap | One family on one screen. The spike's 1 px stripes were finer and closer to a 1997 screen; at 1.5 they would differ from every Quickshell windoid. |
| Palettes are the windoid tokens: `menuSurface`, `bevelLight`/`bevelDark`, `raised`, `menuText`/`menuTextOff`, `menuEdge`; black takes the black bar's `barSurface`, `barText`, `barTextOff`, `ridgeLow` | `checks.titlebars` fails when a token changes and the Lua does not. Cost: the colours live twice. |
| Black is flat: no stripes, no bevel, boxes as dim outlines | The OLED argument that made the top bar black; title bars stay on screen for hours. |
| The window edge is drawn by the plugin, and `border_size` is 0 under Platinum | Hyprland's border is whole logical px. At 1.5 a 1 px border landed as 1 device px on some edges and 2 on others. The frame draws whole hairs outward from where the content lands. |
| No bar on a client that asked to draw its own frame, or never asked (GTK4/libadwaita, GTK3, Chromium with its custom frame enabled); decided from the client's own decoration request | The spike's plan was a hand-kept `no_bar` list of libadwaita classes. The request is what the client said, so no list drifts. Phase A below now asks for SSD on normal Chromium windows; they get our caption and keep native browser tabs. X11 windows keep stock hyprbars' rule. |
| Collapse hides the focused window (`windows collapseActive`); its app's Show brings it back | Hyprland cannot roll a window up to its title bar (WindowShade). Hiding is the nearest thing that keeps the window. Cost: the window leaves the screen instead of leaving its title bar. The spike made it a float toggle, which matches nothing on Mac OS. |
| A double click on the bar zooms, not collapses | Mac OS 8 shades on a double click; here that would hide the window on a stray double click. |
| Both themes now act on release, draw a sunken box while held, and cancel when released off that box | Shared capture handling closes the old Platinum parity gap. Cost: another input state in the patch; a live theme change cancels that state. |
| Groups keep Hyprland's tab bar and get no title bar; the tab bar's indicator takes the title colours | As the spike found, two strips stack otherwise. |
| `hl.plugin.load()` on every parse | See `docs/decisions/hyprland.md`. |

### Original Platinum evidence (before Win98 captions)

Nested Hyprland 0.56.2 under headless labwc, `eDP-1` 2880×1800 at 1.5, the worktree's real `hyprland.lua` and `titlebars.lua` with only the plugin path changed. labwc, Hyprland and every client ran in a bubblewrap namespace whose `/dev` held only `/dev/dri/renderD128`; no seat, no libinput, no `drm: Starting backend`, no `card*` open. Evidence: `/tmp/phase2/` (served at `http://100.114.19.92:8765/phase2/`).

| What | Result |
|---|---|
| Light, dark grey, black, Win98 and back, through the same eval `desktop-theme` runs | as designed; Win98 restores `border_size` 0 and rounding 6 |
| Hairs (`probe.py` down a bar column and along frame rows) | 2 device px each; the bar is 30 px; no gap between frame and content |
| Zoom box, double click, close box, collapse box | maximized and back; maximized and back; the window closed; `qs -c mountainous ipc call windows collapseActive` ran |
| Chromium `--app` (the `web-apps.nix` flags), Ghostty, FeatherPad | bar and frame |
| gnome-text-editor, a normal Chromium window | no bar, no frame |
| A group; fullscreen | no bar; no bar |
| `hyprctl reload` | the plugin stays loaded once, the bars stay |
| CPU with full redraws (`damage_tracking = 0`), 3 windows, one animating, 20 s, two runs each | Hyprland used 1.42–1.45 s with bars and 0.97–1.02 s without: about 0.4 ms of CPU per frame at 60 Hz for three bars. GPU time not measured. |

### Not verified

- Nothing has run on Myoko's GPU, at its 120 Hz, or under a real pointer and Kanata.
- Scales other than 1.5. Hairs are whole device pixels at 1, 1.5 and 2 by construction; odd rungs such as 1.333 are untested.
- Electron, X11 and GTK3 apps: none were run, so whether each gets a bar follows only from what it asks for.
- The collapse box through the real Quickshell: the nested run recorded the IPC call; `hideWindow` is covered by `window-hide.test.js`.

## Native apps: tandem phase 3 (2026-10-27)

`desktop-theme` now derives native toolkit files from the same three preferences
as the chrome and web theme. `set`, `apply`, mode changes, Extra dark and `reapply`
all update GTK, Qt and Ghostty under the existing lock. Win98 preserves Extra
dark but ignores it. Status and refused commands do not change toolkit files.
An ordinary change with a failed session-bus write does not publish a choice
or change native files. Loader recovery is the exception described below.

### What was built

| Part | Implementation |
|---|---|
| One generated source | `scripts/generate-native-themes.py`: five palette ramps, GTK3/GTK4 CSS and raster derivatives, Qt palettes, three Kvantum derivatives and Ghostty configurations/tab strips. The check requires native ramps to match the existing Quickshell colour roles. Upstream widget geometry stays upstream. |
| GTK | `Mountainous-platinum-{light,dark,extra}` from B00merang's Mac-OS-9; `Mountainous-win98-{light,dark}` from Chicago95. Every variant has GTK3 and GTK4 `gtk.css` and `gtk-dark.css`. The dark entry imports that variant, never Adwaita. |
| libadwaita | A managed `@import` block in `$XDG_CONFIG_HOME/gtk-4.0/gtk.css`, following Chicago95's INSTALL.md. Existing unmarked CSS remains. Platinum adds modern libadwaita colour variables; Chicago95 already has its own GTK4/libadwaita port. No global `GTK_THEME`. |
| Qt | qt5ct and qt6ct platform plugins (`QT_QPA_PLATFORMTHEME=qt5ct:mountainous`), with per-user Kvantum directory links to the immutable package (the engine does not search `XDG_DATA_DIRS`); Platinum uses Kvantum, Win98 uses Qt's built-in `Windows` widget style and a generated QPalette. Both get the interface font. Existing Qt fixed-font choices and GTK monospace content stay separate. `QT_STYLE_OVERRIDE` is not set. |
| Myoko's OBS | Select OBS's built-in `com.obsproject.System` in `obs-studio/user.ini`, preserving other keys. Its default Yami stylesheet otherwise masks the platform theme. OBS's INI reader does not trim spaces before `=`; this file uses unspaced delimiters, tested through libobs itself. Close OBS, reapply the desktop theme, then reopen it if OBS saved its old preference on exit. |
| Ghostty | The delivered root config includes writable `mountainous.conf`. ChicagoFLF for Platinum; W95FA Grid for Win98; 8/6 px padding; an AdwTabBar stylesheet through `gtk-custom-css` (Platinum adapts its upstream notebook tab rules; Win98 keeps Chicago95's tab rules). The previous light/dark ANSI ramps remain. That sheet imports the GTK4 derivative and reapplies tab paint and fonts. Win98 tab colours are resolved to literal paint to avoid stale names in GTK's startup provider. Other GTK4 controls can still need an app restart. Ghostty keeps fixed terminal cells with these interface faces, so letter gaps differ from GTK/Qt labels. |
| Runtime | `scripts/apply-native-theme.py` preserves unrelated GTK/Qt INI keys and unmarked GTK4 CSS. It writes generated files atomically, keeps existing permission bits, and creates new files as 0600. These are outputs, not new preference state. The GTK theme name, font and colour scheme are also written through real dconf. |
| Focused check | `checks.native-themes` builds all five appearances and both Qt plugin generations, drives the packaged CLI under private HOME/XDG/D-Bus, checks set/toggle/reapply/Extra dark/bus failure and preservation, checks palette/asset seams and validates every Ghostty configuration with Ghostty itself. Small real Qt5 and Qt6 programs assert the loaded style, resolved font, window colour and a rendered checked indicator for every choice; they use the offscreen platform, not a mock. |

### Decisions made without asking

| Decision | Reason and cost |
|---|---|
| Pin the stable `kdha200501/Mac9KvantumClassic` fork instead of vendoring an expiring download | Its README traces it to DrGordBord's opendesktop product 1766812 and includes GPLv3 text. All Apple-derived artwork remains a flake input. Cost: a fork, not a byte-identical copy of the 2022 zip. |
| Generate CSS and asset colours with Python/Pillow instead of maintaining five SCSS forks | The pinned bases ship compiled CSS and image assets. Declaration-aware conversion keeps text, fields and bevel edges distinct; neutral image ramps change too, including embedded Kvantum PNGs. Checked/unchecked source pairs identify indicator ink so dark checkmarks do not become black edges. Cost: upstream selector/asset changes need visual review, not only a successful build. |
| Qt's `Windows` style for Win98, not another downloaded Kvantum theme | It supplies the classic square Windows widget geometry in both Qt versions, with no additional artwork or licence ambiguity. Cost: native Qt Windows controls are not pixel-identical to Chicago95; app-specific controls and layouts remain the app's. |
| QPA key `qt5ct:mountainous` | Both platform plugins implement `qt5ct` and ignore the optional argument. OBS deletes the bare `qt5ct` string as an old Qt6 crash workaround. The documented `key:argument` form avoids that exact-string blacklist. Cost: it depends on both plugins retaining their current argument contract; the check exercises both real engines. A semicolon is not a theme fallback list. |
| Install Qt5 support as well as Qt6 | Myoko's OBS uses Qt6, but a desktop theme must not silently leave Qt5 apps on another style. Cost: the Qt5 runtime adds closure weight. |
| Extra dark blackens native Platinum surfaces | The native phase explicitly asks for a black appearance. Menus in the existing Quickshell still follow their existing dark-grey tokens; that chrome policy did not change. |
| Keep toolkit files outside Hjem's immutable file links | The switch must be live and must respect XDG directories. Hjem owns only Ghostty's root include. Cost: generated toolkit settings are recreated by `desktop-theme reapply`, not by Hjem alone. |

### Live switching and limits

On the first deployment, Qt apps need a new process with the new platform-theme
and plugin environment. A new login provides it. Changing a running process's
Qt platform plugin is not supported. Existing unmarked GTK4 user CSS stays
after the managed import and can override the native theme.

| Surface | Live behaviour / restart boundary |
|---|---|
| Quickshell, web and compositor title bars | Existing state watchers and title-bar hook; no second preference owner. |
| GTK3 | Unique theme names for all five appearances. Running apps can reload the named theme through dconf. No logout. |
| Plain GTK4 | Named themes can reload, but the higher-priority GTK4 user provider can keep its old stylesheet. Restart for a complete change; no general live user-CSS reload is promised. |
| libadwaita | Its user CSS provider is read at startup. Restart ordinary libadwaita apps after a switch. Native colours, controls and fonts can be restyled; modern header/tab/sidebar layout, app CSS, symbolic icons and animations do not become a historical OS. |
| Ghostty | Ask `org.gtk.Actions.Activate` for `reload-config` on this session's `com.mitchellh.ghostty`. The command first checks `NameHasOwner`, so an absent terminal is never auto-started. No PID scan, signals, synthetic keys or focus changes. Non-single-instance/custom-class launches need their own Reload Configuration action. |
| Qt | qtct can update fonts and palette in running apps, but Kvantum's SVG theme and app-owned styles are not a reliable live interface. Restart Qt apps for a complete Kvantum change. OBS reads its System preference on startup but then forces Fusion geometry. The captures confirm its native palette and font, not Kvantum/Windows geometry. OBS retains its own Fusion geometry, preview canvas and bundled icons. Some icons stay black in dark mode. No OBS source patch was added. |
| Apps that remain outside these toolkits | Zed's renderer, Chromium's own browser chrome, and application-supplied custom widgets are not GTK/Qt styles. Chromium page controls follow the separate web theme. Pyxamp follows its existing face setting, not Qt Widgets. No Flatpak/Snap override was added. |

### Sources and licences

All three sources are non-flake inputs in `flake.nix` and `flake.lock`.
The generated package includes upstream licence/provenance files and a dated derivative change notice. No upstream
artwork was copied into this repository.

| Source | Locked revision | Licence evidence |
|---|---|---|
| `B00merang-Project/Mac-OS-9` | `ca8a5d2a3fb1976cf904133574a3d0022ac2cf71` | Included `LICENSE`: GPL-3.0. |
| `grassmunk/Chicago95` | `5da19b8b1e2a886ebf6628403023d5fac3acc3ee` | Upstream README declares `GPL-3.0+/MIT`; retained in the package. |
| `kdha200501/Mac9KvantumClassic` | `2339bf1239c64c06f2f7c6f2d5f481fef5c16d28` | Included `LICENSE.txt`: GPLv3. README names the original author, product and fork date. Original product's `gplv3` tag is corroboration, not the only licence evidence. |
| ChicagoFLF / W95FA Grid | Existing font inputs, unchanged | Public Domain / SIL OFL 1.1 respectively; see `modules/fonts.nix`. |

### Evidence and what was not verified

Evidence is under `/tmp/tandem/phase3/`, served by the existing server at
`http://100.114.19.92:8765/tandem/phase3/`. The capture uses Myoko's packaged
Ghostty (GTK4/libadwaita), OBS (Qt Widgets), and xdg-desktop-portal-gtk's file
chooser (GTK3). Myoko has no standalone GTK3 editor or libadwaita file manager
in its host/layer package list. Ghostty therefore proves both the terminal
integration and the actual installed libadwaita app; it is not evidence that
all GNOME applications look the same. Qt5 was tested through its real offscreen engine, not a Myoko GUI application.

No SSH, push, deployment, real-session dconf, theme files or Quickshell were used.
No full flake check ran. Every build/evaluation/compositor capture used
`/tmp/phase1/heavy.sh`; builds had no remote builders and one job/four cores.
Myoko's GPU, real input, application state from its running session and scales
other than 1.5 remain unverified. The parent owns review, landing and deployment.

#### Verified results

| Check | Result / evidence |
|---|---|
| `checks.x86_64-linux.native-themes` | Passed, `logs/check-native-themes-17.log`. 54 real Qt5/Qt6 style/font/palette/paint probes; 27 CLI appearance verifications; libobs reads the actual generated key; all five Ghostty configs validate. |
| `checks.x86_64-linux.desktop-theme` | Passed, `logs/check-desktop-theme-complete.log`. |
| Myoko toplevel `drvPath` | Evaluated, `logs/myoko-toplevel-complete.log`: `yf0dck53xifdpjh41ca3sdhqkpc9al2i-nixos-system-myoko-26.11.20260923.4975466.drv`. Not built or deployed. |
| Static checks | Ruff, Python compilation, ShellCheck, the four new/expanded Nix files' Nixfmt check, and the existing web-theme VM test passed. `hyprland.nix` has pre-existing formatter differences; the six-line edit keeps its surrounding style instead of reformatting 400 unrelated lines. Raw Node syntax checking cannot parse Qt's `.pragma library`; the project's VM test handles it. |
| Isolated runtime | `logs/final-capture-4.log` passed. Real Quickshell and packaged Ghostty 1.3.1, OBS 32.2.2 and portal-gtk; 2880×1800 at scale 1.5. No fake application windows. |
| Device/process safety | `session/logs/drm-proof.log`: only `renderD128`, zero card-node FDs. `session/logs/cleanup.log`: **processes left: 0**. The sandbox exposes no card or real input device. |

Reviewed all five primary captures:

| Appearance | Screenshot |
|---|---|
| Platinum light | [platinum-light.png](http://100.114.19.92:8765/tandem/phase3/platinum-light.png) |
| Platinum dark grey | [platinum-dark.png](http://100.114.19.92:8765/tandem/phase3/platinum-dark.png) |
| Platinum extra black | [platinum-extra.png](http://100.114.19.92:8765/tandem/phase3/platinum-extra.png) |
| Win98 light | [win98-light.png](http://100.114.19.92:8765/tandem/phase3/win98-light.png) |
| Win98 dark grey | [win98-dark.png](http://100.114.19.92:8765/tandem/phase3/win98-dark.png) |

`evidence.json` records the windows and chrome state. The GTK3 file chooser
kept PID 1059498 and Ghostty kept PID 1060682 through all five appearances.
OBS was restarted per appearance. `*-live.png` records the boundary before
that Qt restart; it is not a promise that cached Qt artwork changes live.

Measured fidelity gaps for design review: Win98 Ghostty tabs now have the
right live font and paint, but Chicago95's bitmap tab bevels do not appear
in this libadwaita surface; the strip remains flat. OBS adopts the font and
palette but retains Fusion geometry, a fixed grey preview canvas and bundled
icons. Some icon-only OBS actions stay black on dark/black surfaces. These
are app/widget-level gaps, not evidence of a complete GNOME or OBS conversion.
The Win98 title-bar work in the parallel branch is not in these captures.

`closure.json` measures **+122.77 MiB NAR / 21 paths** for the added runtime
package graph. The theme package itself is **3,322,728 NAR bytes**. The baseline
is 148 distinct realised paths from 208 environment-package entries;
`beszel-status` and `nixos-version` were unrealised. This is an estimate against
that package graph, **not** a built-system closure delta. Test-only Qt probes
and libobs do not add runtime packages. The licence report records upstream
claims; no separate artwork-rights review was performed.


### Windows 98 captions (second hyprbars style)

The same `hyprbars-platinum.so` now draws Win98. `titlebars.settings(state)` switches the style, palette, font and square edge live; Win98 ignores Extra dark. Client decoration requests and the group rule still decide whether a bar exists. No class list was added.

On the first deploy that adds this plugin, Win98 captions appear **after the next login**. The stable path keeps the previously loaded library for the current session. `titlebars.lua` probes all seven Win98 options through guarded, read-only `hl.get_config` calls. With the generation-52 plugin it sends no new options: Win98 keeps bars off and the session edge/rounding; Platinum keeps its original appearance. It neither hot-swaps the library nor reports a config error. Release/cancel behaviour also follows the loaded library until login.

The caption is 18 units plus a one-unit seam; the raised frame is three units. Each unit is two device pixels on the window's output. Active/inactive gradients, bevels and glyphs use `Win98Tokens`; `checks.titlebars` compares both palettes, alongside Platinum's. W95FA Grid draws at 25px without smoothing or hinting, with extra advance and a second strike, as `Win98Text.qml` does bold. Pango/Cairo is an explicit dependency. Maximized windows use Restore and no frame; Hyprland's existing maximized gaps remain.

`captionLayout.hpp` shares drawing and hit testing. Compile-time assertions cover the mock's 109/79/45-unit boundaries and widths 1–1024: title first, then the minimize/maximize pair, then Close move to the window menu. The title remains on the taskbar. Both themes now act on release, reverse the held bevel and cancel an off-box release; Platinum's black appearance stays flat. A theme change or reload cancels capture. Minimize retains `windows collapseActive` / `WindowHider.hideWindow`; caption double-click maximizes.

#### Window-menu integration boundary

```
qs -c mountainous ipc call windows menu <address> <x> <y>
```

- Hex address without `0x`; global logical `x`, `y` are the menu's top-left anchor. The caption sends its left edge, below the bar.
- Empty address and `x=y=-1` select the focused window's caption anchor. Alt+Space sends this under Win98; under Platinum it passes through.
- The window-menu worker adds `menu(address: string, x: int, y: int)` to the **existing root** `windows` handler, validates against `windowRows`, and routes to the screen's Desktop. It reuses the taskbar's Restore / Move to Page / Minimize / Maximize / Close menu. No second menu or handler is added here.

The producer is built, and so is the consumer: `windows menu` reaches the Win98 Desktop's window menu (see "Windows 98 taskbar and session parity"); under Platinum it opens that window's strip tile menu. The caption uses a standard document menu affordance, **not an application icon**. App icons, a caption-title tooltip and icon double-click-to-close are deferred. A future shared publisher can atomically write 32×32 PNGs to `$XDG_RUNTIME_DIR/mountainous/titlebar-icons/<address>.png` from the existing app lookup and remove them on close. The plugin should cache by revision and use the document fallback, never resolve icons in its draw loop. No unused reader or publisher is shipped.

#### Cache and verification

The whole caption is one texture per window, rebuilt for title, focus, physical size, palette, held box or maximize/restore changes. The earlier gradient and title were already cached; the avoidable work was 48 face/bevel/glyph rectangles plus two textures **per caption per frame**, even while inactive. The new caption needs one texture draw; the frame retains 12 rectangles.

CPU seconds per 20-second interval, three windows, one spinning page, full redraw at nominal 60 Hz:

| Draw path | Win98 | Platinum | No bars |
|---|---|---|---|
| Before whole-caption cache | 2.26 / 2.03 | 1.45 / 1.40 | 0.86 / 0.91 |
| Whole-caption cache | 1.21 / 1.39 | 1.18 / 1.36 | 0.90 / 0.85 |

Mean Win98 extra CPU falls 66%, from 1.26 to 0.425 seconds. All six new intervals have zero cache rebuilds after warm-up; the CPU harness exits cleanly. The caption has zero changed pixels against the old renderer in a 1410×38 crop. Bevels and text strokes are whole two-pixel steps in both appearances, without blended text edges.

`checks.titlebars` and Myoko toplevel evaluation pass. The private nested Hyprland passes 32 input/caption assertions, including a real title change, empty/long titles, actual narrow rungs, a classless Qt client, Alt+Space, ten live round trips and reload. DRM log/fd scans show no backend, seat, real input or `card*`; only `renderD128` is exposed. Evidence and fixture corrections: `/tmp/tandem/win98-titlebars/` (`DETAILS.md`, `logs/{final-caption,cpu-cached}.log`, `compare/`, `logs/pixels.json`). Real Quickshell menu/hide integration, Myoko's GPU, real input, other scales and X11 remain unverified. No deployment.

## No workspace numbers, and a steel Win98 dark caption (2026-10-27)

Two changes Simon asked for after using Win98 on Myoko. Both apply to both themes where they reach.

### No workspace numbers

Simon: "I don't ever want to see the number of a workspace. The dividers are great, but the numbers are irrelevant. Workspaces are ephemeral for me, not a place you go to explicitly."

Page ids stay internal: they order the strip and the lists, and they go to Hyprland. No label shows one.

`modules/quickshell/page-names.js` is the shared wording. Both themes import it; neither writes its own.

| Function | Text |
|---|---|
| `listNames(names)` | "Signal", "Signal and Zed", "Signal, Zed and Ghostty", "Signal, Zed, Ghostty…" (a divider's tooltip or label) |
| `beside(names)` | "Beside Signal and Zed" |
| `moveBeside(names)` | "Move beside Signal and Zed" (a drag onto another page) |
| `movePages(windows, self, ownPage, shownPage, pageIds)` | The Move to page rows |

Names are app names, once each, in strip order, at most three, then "…" with no space. The Move to page rows list every page of this screen in strip order, the moving window left out of its own page's names. The window's own page is checked and disabled; it reads "On its own" when the window is alone there. An empty page that is not the window's own reads "Empty page". There is no "(showing)" marker. A separator and "New page" end the list; the new page id is still one past every page on every screen.

What changed:

- **Find rows (`find-model.js`, both themes).** The Windows group drops "page N". A window on another screen keeps the screen's name ("tablet"); a window on this screen has no hint, so the Win98 status bar reads "Window". Each screen's windows go page by page: the page the screen shows first, then the other pages where their most recent window falls, with a separator row between pages. A typed query keeps rank order and has no page separators. OmniBar's window rows carry `shown` (`Lanes.isShown`) and an empty `detail`, so the omni card shows no number either, and typing a number no longer finds a page.
- **Platinum.** The Application menu's window submenus name only another screen or "hidden". The tile menu header drops the page ("GitHub, not showing"). Move to page uses `page-names.js`. A strip drag onto another page reads "Move beside …". The strip has no divider labels, so it uses no `listNames` yet.
- **Win98 Find window.** Passes `shown` to the model. The Open dialog lists web pages (URL and title); it never showed a workspace number, so it did not change.
- **Win98 taskbar (later).** The taskbar bands, Move to ▸, Start ▸ Windows and the Cool Switch came with the `win98-taskbar-session` work, which imports `page-names.js`; `no-page-numbers.test.js` no longer lists their files as pending (see "Windows 98 taskbar and session parity"). Hyprland's notifications showed no page numbers; nothing changed there.

Checks: `checks.theme-parity` runs `theme-dev/no-page-numbers.test.js`. It renders every label, hint and detail from `find-model.js`, `menu-models.js`, `strip-plan.js` and `page-names.js` for 48 windows on 12 pages and two screens, in every scope, and fails on `/\bpage\s*\d/i`. It also sweeps the shipped QML and JS for a string ending in "page " joined to a value. Against the code before this change it fails on "page 1". The per-model tests (`find-model.test.js`, `menu-models.test.js`, `strip-plan.test.js`, `page-names.test.js`) assert the same.

### Win98 dark caption: steel

Simon: "In dark mode, the blue title bar is a little bit jarring. Use something more dark-mode appropriate that still feels like Windows 98."

Dark grey's active caption is now steel, `#26364F` → `#56708E`; light keeps Windows Standard's navy, `#000080` → `#1084D0`. The inactive caption is unchanged (`#2A2A2A` → `#4A4A4A`). The menu and list selection takes the same steel, `#41608A` (it was `#2F4FC7`), as Windows Standard's selection takes its caption's navy. The values live in `Win98Tokens.palette()` (`caption1`, `caption2`, `selection`), `titlebars.lua` (`WIN98_PALETTES.dark`) and `scripts/generate-native-themes.py` (dark `caption`, `selected`). `checks.titlebars` compares the Lua and QML palettes; `checks.native-themes` compares the native palette with the tokens. The colours still apply live through `desktop-theme` (`titlebars.apply()`), with no plugin reload.

| White text on | Navy (before) | Steel |
|---|---|---|
| Gradient start | 16.0:1 | 12.2:1 |
| Gradient end | 4.0:1 (below AA) | 5.1:1 |
| Selection | 6.9:1 | 6.4:1 |

Selection against the list background `#1D1D1D` is 2.6:1 (was 2.5:1), and against the face `#3C3C3C` 1.7:1 (was 1.6:1), so level bars drawn in the selection colour are no fainter. Active and inactive stay apart by hue (blue against neutral grey) and by title colour (white against `#9A9A9A`).

The option sheet with five candidates and the pick: `/tmp/tandem/pages-caption/caption/` (served at `http://100.114.19.92:8765/tandem/pages-caption/caption/`). Candidates: dim navy, steel, a slate after Win98's "Slate", a dark teal after "Teal"/"Marine", and charcoal with a thin accent. The scheme names are from memory; their values are approximations, not sampled from a Win98 install. Charcoal was rejected: it is darker than the inactive caption, and its accent line needs a new plugin option.

### Decisions made without asking

- Page separators only for an untouched field. A typed query ranks matches; splitting them by page would move the best match away from the top.
- Pages after the shown one are ordered by recency, not by id: the most recently used window's page comes second.
- The omni card's window detail is empty rather than the app name; the card already heads each screen's group.
- The selection changes with the caption, in QML, GTK, Qt and Ghostty. Level bars use the selection colour, so they change too.

### Evidence

Evidence: `/tmp/tandem/pages-caption/` (served at `http://100.114.19.92:8765/tandem/pages-caption/`), `index.html` pairs each shot before (cairn `2d713979`) and after. The real Quickshell ran in a nested Hyprland 0.56.2 under headless labwc, 2880×1800 at 1.5 with a second output "SUNSHINE", with the hyprbars plugin built from cairn's patch and each tree's own `titlebars.lua`. labwc and Hyprland ran in a bubblewrap namespace whose `/dev` held only `/dev/dri/renderD128`, with `AQ_DRM_DEVICES` and `SEATD_SOCK` set to missing paths. The Hyprland logs have no `drm: Starting backend`, seat or libinput line, and an fd scan found 0 `card*` nodes (`logs/{before,after}/drm-proof.log`). Shots in dark grey and light:

- Platinum: Find menu (Super+P), Application menu ▸ GitHub's three windows, tile menu ▸ Move to page, a strip drag onto page 3.
- Win98: the Find window, Start, and hyprbars captions. The caption sequence shows navy before, steel after, navy in light, and steel again after a live switch with the plugin still loaded.

### Not verified

- Nothing ran on Myoko, its GPU or real input.
- The GTK, Qt and Ghostty dark Win98 appearances were checked by `checks.native-themes` (palette agreement), not by a screenshot.
- These shots predate the Win98 taskbar work: they show its taskbar numbers, since removed.
## Chromium outer chrome: Phase A and next phases

Simon wants "completely our own outer chrome". Phase A delegates normal
Chromium's caption and outer frame to the existing patched hyprbars. It does
not replace the browser's tabs, navigation toolbar, menus or settings. Cost: one
extra caption row above the native tab strip.
Configuration, migration safety and pinned sources are in
[`web-apps.md`](../decisions/web-apps.md#normal-browser-windows-phase-a-2026-10-27).

### Phase A: bounded frame integration

`modules/chromium-frame.nix` seeds the first profile in new Chromium user-data
roots with system frames and GTK theme mode. A pre-compositor login service
changes only the frame preference in stopped existing profiles, in both known
Chromium user-data roots. It skips roots with a live local Chromium lock or a
foreign/unknown lock, preserves
unrelated data and permissions, and keeps one original backup. Stale local
locks (dead PID or a PID reused by another program) do not block migration and
remain untouched for Chromium to clean up. Existing theme choices remain;
select **Use GTK** in Chromium's Appearance settings to opt into the native
palette. `desktop-theme` remains the
only appearance owner. No Chromium theme extension is generated in this phase.

`checks.chromium-frame` checks Myoko's module wiring, the packaged CLI and private
profile migration: preservation, backup, idempotence, permissions, missing roots,
multiple profiles, malformed files, live Chromium locks, stale local locks,
foreign-host locks and unknown lock formats.

Evidence: `/tmp/tandem/chromium-frame/`, served at
<http://100.114.19.92:8765/tandem/chromium-frame/>. No deployment, SSH or real
Chromium profile was used. Myoko's actual GPU, input devices and live profile
remain untested.

#### Verified frame behaviour

The real Myoko package, Chromium **153.0.8010.52**, ran under nested Hyprland
**0.56.2**, with the current patched plugin, at 2880×1800 / scale 1.5. The harness
asserts the saved theme name and `plugin:hyprbars:win98` before every capture and
input assertion: false for Platinum, true for Win98. It never contacts the real
Hyprland instance.

| Behaviour | Platinum | Windows 98 |
|---|---|---|
| Normal browser at startup with `custom_chrome_frame=false` | Our striped caption/frame | Our navy caption/frame |
| Chromium window controls in the tab strip | None; tab close buttons remain | Same; no duplicate minimize/maximize/close |
| Caption maximize / restore | Pass, real pointer clicks, modes 1 → 0 | Pass, including Restore glyph |
| Chromium F11 / F11 | Fullscreen mode 2, no caption or browser toolbar; returns to mode 0 | Same |
| Floating caption drag | (160,180) → (250,250) | Same |
| Floating drag from empty tab-strip area | (250,250) → (300,290) | Same |
| First-run initial preferences | Actual patched `/etc/chromium/initial_preferences` seeds frame=false and GTK=1 in a fresh profile | Same package-wide seed |

`logs/runtime-5.log` records **15 passing assertions, zero failures**. The
private running-profile preflight also logs that it defers the locked root.
`logs/check-lock.log` and `check-lock-output.log` record the review follow-up's
passing Nix check and 12 migration tests, after rebasing onto `cairn` at
`2d713979`. The original blanket lock check could skip logout-killed Chromium
profiles forever; the follow-up verifies dead PIDs, reused PIDs and live local
Chromium processes without deleting any lock. Ruff, Python compilation, the new module's Nixfmt
check and `git diff --check` pass.

The protocol log records an explicit SSD request (`set_mode(2)`) at startup.
The in-process preference observer exists, but the private false → true → false
CDP roundtrip did **not** fully restore our caption: the second false removed
Chromium's close button without issuing another SSD request. Restart is the
verified path. No live CDP preference automation ships.

The harness corrections matter: its first Win98-labelled image still showed
Platinum because `HYPRLAND_INSTANCE_SIGNATURE` was missing and the theme hook
correctly skipped the compositor. That image is archived under `failed-harness`,
not used as final evidence. A drag needs a threshold motion **and** a subsequent
motion; the original one-motion fixture started a drag without moving it. The
final run uses real two-motion gestures and prints the step, option and full
window state on failure. The private bus needs dconf's service directory; GTK
also needs the session's dconf GIO backend, not just a working dconf CLI.

`logs/drm-proof.txt` records zero card-node FDs. Both compositors and clients run
in a `/dev` namespace with only `renderD128`, no card or real input nodes.
`AQ_DRM_DEVICES` and `SEATD_SOCK` name nonexistent paths. The Hyprland log has no
DRM backend, seat or libinput startup. `logs/cleanup.log`: **processes left: 0**. A final independent scan of both
private-runtime environments and evidence-path command lines also finds zero
processes (`logs/process-scan.json`).
Tab tear-out/rejoin, X11, scales other than 1.5 and real Quickshell minimize/menu
integration were not retested in this phase.

#### GTK tab strip: measured result

GTK mode does improve the existing strip without a theme extension. It uses
Chromium's GTK3 **3.24.52** backend with dconf. The private harness must carry
Myoko's `GIO_EXTRA_MODULES` from the NixOS Wayland/dconf module; otherwise GTK
uses default settings even though `dconf write` succeeds. `logs/gtk-libraries.txt`
records the loaded GTK3 library and `libdconfsettings.so`. `logs/gtk-mode-pref.json`
records system theme 1 after the real Settings **Use GTK** action.

All five palettes changed live in browser PID **3144025**. A sample in the empty
tab-strip background at device (1800,80) is below (`logs/gtk-colours.txt`). This
is measured browser paint, not the compositor caption or a token definition.

| Appearance | Browser strip RGB | Screenshot crop |
|---|---|---|
| Platinum light | 220,220,220 | [Platinum light](http://100.114.19.92:8765/tandem/chromium-frame/gtk-platinum-light-off-chrome.png) |
| Win98 light | 192,192,192 | [Win98 light, live switch](http://100.114.19.92:8765/tandem/chromium-frame/gtk-win98-light-off-chrome.png) |
| Win98 dark | 60,60,60 | [Win98 dark](http://100.114.19.92:8765/tandem/chromium-frame/gtk-win98-dark-off-chrome.png) |
| Platinum dark grey | 58,58,58 | `gtk-platinum-dark-off.png` |
| Platinum extra black | 0,0,0 | [Platinum black](http://100.114.19.92:8765/tandem/chromium-frame/gtk-platinum-dark-on-chrome.png) |

The colours follow `desktop-theme` live. The tab glyphs retained the startup
font across a live Platinum ↔ Win98 switch; restart Chromium for the other
family's font. A fresh Win98 process does pick up W95FA Grid: [Win98 light
startup](http://100.114.19.92:8765/tandem/chromium-frame/gtk-win98-light-startup-chrome.png)
and [Win98 dark](http://100.114.19.92:8765/tandem/chromium-frame/gtk-win98-dark-startup-chrome.png).
`logs/gtk-font.log` verifies the Win98 option for both; its cleanup also reports
zero processes. The strip, rounded tabs, toolbar geometry and icons are still
Chromium's, not GTK widgets or historical OS controls. This is a native palette
and startup font, **not** a complete Platinum/Win98 browser. A generated theme
extension would add controlled paint/images, not replace that geometry or fix
font caching; estimate **1–3 days** for five manifests, reproducible loading,
live-switch handling and checks. GTK is the lower-cost choice for Phase A.
A design engineer should review the remaining geometry, font and icon gaps.

`logs/gtk.log` records a complete five-appearance run and a fresh-process black
capture. `logs/gtk-pids.json` proves one PID for the five live captures and a new
PID after restart. `logs/gtk-drm-proof.txt` has zero card-node FDs, and
`logs/gtk-cleanup.log` reports **processes left: 0**. The full GTK captures contain
a test-only DNS-blocking flag banner; the linked crops focus on the caption,
tabs and toolbar. That flag is not shipped.

### Next phases: options and costs

These are planning estimates, not commitments. Each option retains Phase A as
the fallback. Do not replace the daily browser before a private-profile trial.

| Option | Work estimate | Main risk / maintenance cost | What Simon loses |
|---|---|---|---|
| Keep Chromium's tabs, theme their paint | 1–3 days for generated theme manifests, pinned loading and five-appearance checks | Theme `colors`/`images` can repaint, not change tab geometry or toolbar ownership; live extension swaps need a supported installation/update path | The ideal: Chromium still owns most browser chrome |
| `--app` page windows, Hyprland groups as tabs | 3–7 days for a prototype; 1–2 weeks for restore, popups, focus and input tests | Group membership is not Chromium tab state. Existing `CdpBrowser.adopt` closes opener targets and relaunches URLs: unsafe for stateful popups. Must fix target/window identity before expanding it | Native tab search, tab groups, pinned tabs, drag-between-windows, standard browser toolbar and extension buttons unless rebuilt |
| `--app` or kiosk Chromium plus Quickshell tabs/address bar over CDP | 1–2 weeks for an isolated prototype; 4–8 weeks for daily-use parity | Must map targets to windows, handle crashes, history, downloads, permissions, security/origin UI and popup routing. Kiosk hides escape/navigation affordances. CDP is a privileged local control endpoint, not a stable public browser-shell API | Existing tab UX, browser toolbar, built-in accessibility and extension UI until replaced; kiosk also loses ordinary window behaviour |
| WebKitGTK browser shell | 6–12+ weeks for daily-use basics | New engine integration, security updates, auth/DRM/site compatibility, permissions, downloads and accessibility become our responsibility | Chromium extensions, profile/session compatibility, some sites and media support |
| Qt WebEngine browser shell | 6–12+ weeks for daily-use basics | Separate embedded Chromium lifecycle, Qt packaging, security release lag and DRM/site testing; QML UI still needs complete browser semantics | Chromium profile reuse, normal Chrome extension ecosystem and ready-made browser UI |

**Recommendation:** keep Phase A for normal browsing. Build the `--app` plus
Hyprland-group path next, behind a separate launcher and private profile. It
matches the current one-page/one-window model and keeps Chromium's renderer,
cookies and DevTools without taking on a whole embedded browser. Its first
milestone must keep live pages, not close and recreate a URL to imitate a tab.

| Phase | Deliverable | Exit criteria / fallback |
|---|---|---|
| A (this branch) | Our caption/frame; GTK paint where selected; native Chromium tabs retained | Both themes, maximize/restore, F11, caption dragging, safe migration and reproducible Nix check. No live-profile edit in tests |
| B (prototype only) | Two `--app` windows as a Hyprland group; shared target/window registry in the existing CDP owner | Duplicate same-host pages, navigation, authentication popup, window.open, detach/regroup, close/restore and browser restart preserve state. Keep ordinary Chromium one action away |
| C (design then build) | Our group strip and address/security surface, both themes together | Design engineer specifies tab overflow, keyboard/focus, title/origin distinction and permission/download affordances. Existing controls stay reachable in narrow tiles. Fix the current group rule (no caption) before claiming our own full outer chrome |
| D (trial) | Optional Quickshell/CDP shell if group tabs prove too limiting | Weeks of opt-in daily use, accessibility and failure/recovery tests, threat review of CDP. Keep Chromium settings/DevTools and normal-browser escape hatch |
| E (only if needed) | Evaluate WebKitGTK/Qt WebEngine with a fixed site/media/auth matrix | Switch engine only if Chromium/CDP limits block a concrete requirement. Profile export/rollback and security-update ownership come first |

A generated Chromium theme is a lower-cost cosmetic alternative to B, not a
route to complete ownership. Theme manifest documentation:
<https://developer.chrome.com/docs/extensions/develop/ui/themes>. It can reuse
our existing tokens; it cannot turn modern rounded tabs into our caption or
replace Chrome's navigation controls. A design engineer must review that gap.

### Loader recovery after native integration (2026-10-27)

Confirmed regression: the loader used `desktop-theme set platinum` after a
broken load. With no session bus, dconf returned 1 before the name was saved.
The old Desktop stayed mapped but `theme-name` stayed `broken`, so the lifecycle
check timed out. Giving only the test a healthy bus would hide a real failure.

`desktop-theme rollback <failed-theme> <fallback-theme>` now compares the raw
stored ID under the existing lock, validates the fallback, and atomically saves
the fallback before native work. It preserves mode and Extra dark. A delayed
callback does nothing if another choice has replaced the failed ID. Native
synchronisation is best effort for recovery only; a failure reports that native
files may lag and a later `reapply` repairs them. Ordinary `set`/`apply` keep their
strict failure behaviour. No pending-state file or second preference owner was
added. A storage write failure still returns an error; recovery cannot bypass
an unwritable state directory.

The lifecycle test explicitly disconnects both buses and exercises the real
loader, packaged command and atomic state file. CLI/native tests cover a failed
bus, a refusing native writer, preserved mode/Extra dark, stale recovery,
invalid fallbacks and successful reapply.

Recovery validation: `desktop-theme-shell`, `desktop-theme`, and `native-themes`
all passed, one at a time through `/tmp/phase1/heavy.sh` (logs:
`/tmp/tandem/phase3/logs/rollback-{desktop-theme-shell,desktop-theme,native-themes}.log`).
The exact previously packaged command reproduced exit 1 and `theme-name=broken`;
the new packaged recovery command returned 0 with `platinum dark on` intact
while reporting the disconnected bus and stale native settings. Nixfmt, the
focused CLI/native ShellCheck and the lifecycle Node parser passed. The two
legacy capture scripts retain their pre-existing ShellCheck warnings; their
syntax checks passed. No SSH, push or deployment ran.

### Picker teardown callback lifetime (2026-10-27)

The landing lifecycle run exposed an intermittent `QQmlVMEMetaObject` invalid-
context warning. The fixture keeps Appearance open through its 20 theme swaps.
Platinum's picker queued `revealFocused` with `Qt.callLater`; a theme swap could
destroy its QML context before invocation. The old guard inside that function
was too late: Qt rejected entry into the invalid context itself.

Focus and geometry changes now restart one zero-interval timer owned by the
picker. Destroying the view cancels that work. Focus reveal remains deferred
and coalesced; no layout, palette or rollback policy changed. An owner-only
`ThemeDesktop` rewrite still reproduced the warning and was reverted. The
production loader and strict lifecycle warning filter are unchanged.

`desktop-theme-shell` passed three consecutive real executions, including two
forced `--rebuild` runs of the same derivation. This covers 60 theme swaps,
three disconnected-bus rollback cases and 27 picker geometry cases per run.
Logs: `/tmp/tandem/phase3/logs/rollback-picker-shell-{1,2,3}.log`.

The focused `desktop-theme`, `native-themes` and `win98-desktop` checks also
passed serially through the heavy guard; their logs use the same
`rollback-picker-` prefix. Boundary lint, QML parser and whitespace checks
passed. Standalone `qmllint` exited 0 with the same 71 metadata/unqualified
warnings as the unmodified picker (no added warnings); the real Quickshell
checks supply the authoritative type/runtime validation. No full flake check,
SSH, deployment or push ran.

### Win98 view-owned deferred work (2026-10-27)

The Win98 follow-up replaces 36 `Qt.callLater` sites in 15 view files with
22 zero-interval owner timers. This covers the picker, tray windows and frame,
status bars, Find/Open, the omni view, Fleet and glance. Destroying a view now
cancels its pending measure, layout, focus or action callback. Calls on shared
singletons remain unchanged. The Desktop, taskbar, menu host and Start model
are deliberately outside this change.

Each operation coalesces pending work until the timer tick. Fleet's reveal
keeps the selected-name argument; omni actions keep the last argument pair
and release it before dispatch. The omni action timer belongs to the Desktop's
view scope, not the Find/Open window it may close. Cost: work can wait until
the next timer/animation tick rather than the next JS event-loop turn.

The Find reveal timer also follows viewport/content-height changes: output
mapping can settle those bounds after selection has moved. This preserves
the selected-row visibility contract without changing the layout arithmetic.
The switch, Fleet and Find warning scans now reject `QQmlVMEMetaObject` too;
the shared lifecycle warning filter remains unchanged.

Validation: the final `win98-desktop`, `win98-fleet` and `desktop-theme-shell`
checks passed serially through `/tmp/phase1/heavy.sh`. Desktop includes 147
switch checks and 102 Find checks; Fleet passed 140 checks. Fleet needed one
retry: the first final run failed only `fixture stale reaches its state`
(139/140), without a QML warning. This fixture timing remains a follow-up.
The focused Find repeat also passed all 102 checks after viewport
reconciliation. Pinned base `a560dcdd` had independently failed Start > Find
and short-viewport selection checks before this change.

Project qmllint is clean for all 61 Win98 files; parser checks for the 15
changed QML files, boundary lint, Bash syntax and whitespace checks passed.
Evidence: `/tmp/tandem/phase3/logs/win98-timer-final-*.log`,
`win98-timer-find-reconcile.log`, `win98-timer-desktop-baseline.log` and
`win98-timer-lint.log`. No full flake check, SSH, deploy or push ran.

## Windows 98 taskbar and session parity (implemented)

Spec: the approved parity mock at `/tmp/tandem/win98-parity-mock/` (`REPORT.md`, `DIRECTION.md`, items 3–9), with every default in its decisions table accepted. Later rule from Simon, for everything built here: **a page (workspace) is never numbered on screen.** Pages are ephemeral, not places; a page is named by the apps on it.

### What was built

| Part | Files |
|---|---|
| The Win98 taskbar's own window list: windows shown on this screen plus hidden ones whose home is here, each in its home page's band; a minimized window keeps its raised button | `themes/win98/task-model.js` (`lane`), `Win98Desktop.qml` (`laneEntries`, `pageOf`, `isMinimized`, `clickWindow`), `Win98Taskbar.qml`. `lanes.js` and Platinum are unchanged |
| A click on the active button minimizes (the shared hide); a click on a minimized one restores it alone, focused | `window-hide.js` `showWindow`, `hideScreen`, `setHome`, `homeOf` (+ tests); `WindowHider.qml` |
| The window menu (a button's right click, Shift+F10 or the Menu key on a focused button, the windows IPC): Restore, Move to ▸, Minimize, Maximize, Close (bold, Alt+F4) | `task-model.js` (`windowMenu`), `page-names.js` (`movePages`), `Win98MenuHost.qml` (`winmenu`, placed at a point), `Win98Desktop.qml` (`windowMenu`, `perform`) |
| The taskbar's own menu (a right click where no control takes it): Minimize All Windows, Minimize Other Windows (Hide Others), Restore All Windows (Show All), Find... Super+P | `task-model.js` (`taskbarMenu`), `Win98Taskbar.qml` (the bar's background), `Win98MenuHost.qml` (`tbmenu`) |
| `windows menu <address> <x> <y>` on the existing root `windows` handler: hex address (or "" for the focused window), validated against `windowRows`, routed to that screen's Desktop; -1 -1 is the window's own corner (Hyprland's `at`) | `shell.qml` (`windowMenu`, `shownPageOn`); `Win98Desktop.windowMenu`; `PlatinumDesktop.windowMenu` opens that window's strip tile menu rising from the point |
| Held Super+Tab: the Cool Switch over windows, on the existing `chrome cycle` messages | `app-model.js` `windowCycleStart` (+ tests with out-of-order messages), `Win98Desktop.cycle()`, `Win98CoolSwitch.qml` (layer `mountainous-coolswitch`, no input) |
| Start ▸ Lock Myoko (at once); Start ▸ Shut Down... opens Shut Down Myoko over the whole screen's black checker (`Win98Dither`), the taskbar included: Stand by, Shut down, Restart, Log off simon; the last OK'd choice is kept in `$XDG_STATE_HOME/mountainous/win98-shut-down`; the red "Open windows close without saving." under the three that close windows. Log Off simon... keeps its confirmation | `Win98ShutDownScreen.qml` (layer `mountainous-shutdown`), `themes/win98/session-model.js`, `Win98Desktop.runSession` (Platinum's commands, literal argv) |
| Start ▸ Settings ▸ System...: System Properties ▸ General, the facts of Platinum's About | `Win98SystemProperties.qml`; `SystemFacts.qml`, one reader now shared by `PlatinumAboutWindow.qml` |
| Start ▸ Documents (Recent Applications, 15, "web app" hint, "(Empty)") and Start ▸ Favorites (the pinned web apps, their lettermarks), launched through `Launcher` exactly as Platinum's | `start-model.js` (`favorites`, `documents`, `top`), `Win98Desktop.qml` (`launchWebApp`, `launchRecent`), `Win98MenuPanel.qml` (`themeIcon`: an icon-theme icon in a menu row) |
| The volume and brightness pop-up: a raised box above the tray icon (above » or Start when the icon moved), the block bar and the value, 1.5 s, no input; Platinum's arming rules (none for values loaded at start or a new output device, none while a menu or window is open here) | `Win98VolumePopup.qml` (layer `mountainous-popup`), `session-model.js` (`popupPlan`), `Win98Desktop.qml` |
| Super+O: the tray draws B W S L C D F R N; N opens Notifications under Win98 too | `tray-model.js` (`CHORD.ntf`), `modules/hyprland/hyprland.lua` |
| No page numbers: band dividers carry no number (a click still shows the page; the tooltip names the band's apps, "Signal and Zed"); Move to ▸ names each page "Beside Signal and Zed", the window's own page checked and grey ("On its own" when alone), "Empty page", then "New page"; Start ▸ Windows and the chevron menus separate pages with separators | `page-names.js` (shared), `task-model.js` (`pageWindows`), `start-model.js`, `Win98Desktop.qml`, `Win98MenuHost.qml`, `Win98Taskbar.qml` |
| Icons | `themes/win98/icons/{favorites,documents,lock-computer,computer,system,maximize,restore}.svg`, from the mock by `themes/win98/dev/make-parity-icons.sh` |
| Checks | `checks.win98-taskbar` (new: `theme-dev/win98/taskbar.sh` and the pure tests), `checks.win98-desktop` (the new pure tests; `switch.sh` opens the window menu, taskbar menu, Shut Down, System Properties, the Cool Switch or the pop-up before Win98 swaps; `geometry.sh` checks them from 360x640 up), `bar-delivery` |

The contract grows: a Desktop may implement `windowMenu(address, x, y)` (screen-local logical px). `context.shell` gains `shownPageOn(name)`. `WindowHider` gains `hideScreen`, `showWindow(address, fallbackPage, focus, after)`, `setHome` and `homeOf`. `app-model.js` gains `windowCycleStart`.

### Decisions made without asking

| Decision | Reason / cost |
|---|---|
| Pages are named with the shared `page-names.js` (`listNames`, `beside`, `namesOn`, `movePages`); `task-model.js pageWindows` gives it the lane, minimized windows on their home pages | One wording for both themes. `no-page-numbers.test.js` no longer lists `Win98Desktop.qml`, `Win98MenuHost.qml` and `start-model.js` as pending |
| Deferred session and menu actions run from zero-interval timers the Desktop owns, not `Qt.callLater` | A theme swap that destroys the Desktop cancels them (the same pattern as the Win98 views' owner timers); the new windows defer nothing |
| Shut Down Myoko is its own Overlay surface, but still MenuState's `shutdown` | The checker must cover the taskbar, which the menu host's surface leaves out; MenuState keeps one menu or window open at a time. A press on the checker does nothing (modal, as Win98) |
| System Properties is a menu-host window (MenuState `sysprops`), centred like Log Off | One window at a time, like the tray windows; a click outside closes it. Cost: it does not stay open beside a tray window |
| The page band's head (etch, grip and the old number's place) is one flat click target, raised under the pointer, pressed while held; the sunken "page on screen" box went with the number | An empty sunken box said nothing (seen in the captures). Cost: the band no longer marks the page on screen; its active window's button still does |
| Maximize is Hyprland's `maximized` fullscreen state (the taskbar stays), focusing the window first in one batch; Restore of a maximized or fullscreen window toggles that state | Win98's maximize kept the taskbar. Maximize on a minimized window restores it and maximizes in the same batch |
| Move to ▸ on a minimized window changes only its home page (`WindowHider.setHome`) | The mock's rule: it stays minimized; Restore puts it there |
| Restore All Windows acts on every screen (it is the shared Show All); Minimize All and Minimize Other act on this screen | As Platinum's Show All and Hide Others |
| Minimize Other keeps the front window's app (Hide Others), not only the front window | The brief: "= Hide Others" |
| The Cool Switch takes every window on every screen, hidden ones included; a commit on a hidden window restores it alone | Alt+Tab listed every window; the title box says "(minimized)" |
| `checks.win98-taskbar` is its own attribute | `taskbar.sh` adds about five minutes; with the rest of `win98-desktop` one build could pass the 15-minute step |
| **Win98MenuPanel's clipper height is snapped to the unit for every roll** | Measured in the sandboxed session: a cascade under a menu whose top level does not roll (the window menu) never received hover or presses (0 of 3 points); with the snapped height, 3 of 3. The Start menu worked only because its top level rolls. Cause not found; the fix keeps the panel's geometry identical to a finished roll |
| The context menus appear at once (no roll) | The motion table: menus from the taskbar appear at once |

### Evidence

Headless sway in a bubblewrap namespace with its own PID namespace, no DRI node in `/dev`, a tmpfs over `/run/user`, `/run/dbus` and `/run/systemd`, Qt on llvmpipe; the real `ThemeDesktop` and `Win98Desktop` over the harness's windows and a `WindowHider` with `window-hide.js`'s own rules. `loginctl`, `systemctl`, `systemd-run` and `hyprctl` are logging stubs (`session.sh`). Evidence: `/tmp/tandem/win98-taskbar-session/` (http://100.114.19.92:8765/tandem/win98-taskbar-session/).

| Run | Result |
|---|---|
| `checks.win98-taskbar`: `taskbar.sh` (minimize and restore by click, the window menu and Move to, the taskbar menu, the windows menu call, held Super+Tab with stale and late messages, Lock, Shut Down Myoko, Log Off, System Properties, Documents, Favorites, (Empty), the pop-up, and no page number in eight surfaces), the pure tests, `app-model` and `window-hide` tests | 81 of 81 |
| `checks.win98-desktop`: `behaviour.sh`, `switch.sh` (the window menu, taskbar menu, Shut Down, System Properties, the Cool Switch and the pop-up each mapped under niri before a swap, and gone after it), `geometry.sh` (32 new bounds checks at 360x640, 800x480, 1280x360 and 1920x1200), `scales.sh`, `find.sh`, the pure tests | 33, 147, 82, pass, 102 |
| `checks.theme-parity` (no listed gaps; `no-page-numbers` with nothing pending), `win98-fleet` (140), `platinum-desktop`, `bar-delivery`, `win98-theme`, `desktop-theme-shell`, `desktop-safety`, `titlebars`; the Myoko toplevel `drvPath` | pass; evaluates |
| Session commands | Only the stubs ran: `loginctl lock-session`, `systemctl suspend`, `systemctl reboot`, `hyprctl … hl.dsp.exit()`, and two `systemd-run` launches (`logs/taskbar-commands.log`); `/run/dbus` and `/run/systemd` were empty tmpfs mounts |
| Isolation | No `/dev/dri` in the namespace, no card or input fd in any process, no `drm`, seat or libinput line in sway's log (`proof/scan.txt`) |
| Screenshots | `shots/` (the mock's state names, light and dark grey, 1920x1200 and 360x800) and `compare/` (the mock beside the build) |

Not in the mock: System Properties reads the sandbox host's real name and DMI product (Zao), and the band heads carry no number.

### Not verified

- Nothing ran on Myoko, under Hyprland, or with a real pointer, keyboard or Kanata. Shift+F10 and the Menu key on a focused taskbar button were not pressed.
- The windows IPC through `shell.qml` itself: the harness reproduces its routing; `shell.qml` only compiled. Whether Hyprland's `at` is just under a Win98 caption with hyprbars' `bar_part_of_window` is inferred, not measured.
- Maximize and Restore dispatch the Lua strings shown; they were logged, not run in Hyprland.
- Two screens: a window minimized on a screen that left falls to the primary screen's taskbar (unit test only).
- The page names come from the fixtures' app names; real desktop entries were not read.

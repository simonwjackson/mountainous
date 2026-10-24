# Desktop themes for Myoko

Status: phase 1 implemented on the a05c2ead base; phase 2 (Windows 98) implemented on b7f20f04. Written 2026-10-23. No deployment.

Base: `cairn` at `a05c2ead` ("dark grey Platinum bar and an Extra dark toggle"). The later `77dd2791` bevel/shadow change is not included; that line has not landed on `cairn`.

Later (2026-10-24): the `77dd2791` bevel and cast shadow were ported onto the phase 2 layout. `PlatinumTopBar` draws the bevel hairs, `PlatinumTokens` holds `barRaised`, `barBevelLight`/`barBevelDark` and `barShadowHeight`/`barShadowTop`, and `PlatinumDesktop` owns one `PlatinumBarShadow` window per screen (layer namespace `mountainous-bar-shadow`, no exclusive zone, empty input mask, visible with its bar). Extra dark stays flat. Platinum therefore maps three layer surfaces, not two; `theme-dev/win98/switch.sh` expects the shadow. `checks.bar-shadow` runs the window under labwc. The registered Platinum thumbnails predate the bevel. Evidence: `/tmp/ship-prep/shots/`.

## Goal

Simon can switch the whole desktop chrome between a handful of themes: Mac OS 8 Platinum and Windows 98 first, more later. Each theme has its own bars, menus, controls, font and colours. The picker draws itself in the style of the current theme. A switch is live, with no restart and no logout.

## What a theme is

A theme is a set of prefixed QML files plus one entry in a list. Assets and pure policy code live in its folder. Phase 1 tried the original folder-based QML plan and used the specified flat fallback after the dynamic-load spike failed. It is not a palette file. Omarchy's model (one `colors.toml`, rendered into each app's config) cannot express a bevel, a bottom taskbar or a cascading Start menu. Its staging step, the live IPC switch, and the "on-screen apps first" order are still worth copying. See the Omarchy notes at the end.

| A theme decides | Platinum | Windows 98 |
|---|---|---|
| Which bars exist, on which edge | Top menu bar, plus the dock (restyled later) | One bottom taskbar, no dock |
| Where window switching lives | Dock | Taskbar buttons, banded by page |
| Launcher entry | Omni mark opens the omni bar | Start menu; Run... opens the omni bar |
| Status controls | Bar titles with readouts | Tray icons with tooltips |
| Menu shape and direction | Hangs down from its title | Rises from the tray; Start cascades up and right |
| Components | `Platinum*` set | New Win98 set |
| Font | ChicagoFLF | W95FA |
| Appearances | Light, dark grey, plus Extra dark (black bar) | Light (Windows Standard), dark grey |
| Picker view | Appearance control panel | Display Properties |

Shared by every theme, never forked:
- the data owners: Pipewire, Bluetooth, Wi-Fi, brightness, `OciEgress`, `StorageHealth`, `BuilderGate`, `Notifications`, `Dictation`, `Lanes`, the clock;
- the logic modules and their tests: `MenuState`, `battery.js`, `oci-model.js`, `notification-model.js`, `builder-gate.js`;
- what stays unthemed: the omni bar, notification popups, the dictation overlay, app windows, GTK.

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

`hyprland.lua` today calls `qs -c mountainous ipc call topbar reveal` for the Super+O chord. That name is Platinum's. The `chrome` target now forwards `reveal`, `hide`, and `open <control>` to the active Desktop. `topbar` remains an alias; `chrome toggle` retains the whole-chrome immersive toggle. Win98 maps the same chord letters to its tray icons, and Ctrl+Esc opens Start (`chrome open start`). Super alone is not bound; see the phase 2 decisions.

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
| 3 | Mac OS 8 bottom app bar (backlog card) | Platinum dock |

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

A candidate must create all chrome in its Desktop and honour `active`. A compilation/creation error keeps the old object, closes the menu, calls `desktop-theme set <previous>`, and sends one primary-screen notification with the failed ID and Qt error. The fixture's broken type is never delivered to hosts. Runtime binding warnings are not a Loader Error: each new theme must still pass the warning-free engine test.

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

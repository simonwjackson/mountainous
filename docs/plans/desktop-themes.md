# Desktop themes for Myoko

Status: phase 1 implemented on the a05c2ead base; phase 2 (Windows 98) implemented on b7f20f04; phase 3 (Platinum Apple menu, Application menu and Control Strip) implemented on 37c91c12. The quiet-glyphs top bar (direction A) implemented on f47035fc. Written 2026-10-23. No deployment.

Base: `cairn` at `a05c2ead` ("dark grey Platinum bar and an Extra dark toggle"). The later `77dd2791` bevel/shadow change is not included; that line has not landed on `cairn`.

Later (2026-10-24): the `77dd2791` bevel and cast shadow were ported onto the phase 2 layout. `PlatinumTopBar` draws the bevel hairs, `PlatinumTokens` holds `barRaised`, `barBevelLight`/`barBevelDark` and `barShadowHeight`/`barShadowTop`, and `PlatinumDesktop` owns one `PlatinumBarShadow` window per screen (layer namespace `mountainous-bar-shadow`, no exclusive zone, empty input mask, visible with its bar). Extra dark stays flat. Platinum therefore maps three layer surfaces, not two; `theme-dev/win98/switch.sh` expects the shadow. `checks.bar-shadow` runs the window under labwc. The registered Platinum thumbnails predate the bevel. Evidence: `/tmp/ship-prep/shots/`.

## Tandem rule and parity ledger (from 2026-10-27)

Platinum and Windows 98 move together. A feature lands for both themes in the same phase, or this ledger records why one theme has no counterpart. New theme work updates this table when it lands. Fleet data, launches, windows and session actions stay in the shared owners; each theme draws its own view.

| Feature | Platinum | Windows 98 | Win98 counterpart |
|---|---|---|---|
| Status controls (Bluetooth, Wi-Fi, Sound, Brightness, OCI, Disks, builder gate, Notifications, Dictation, battery, clock) | Done | Done | Tray icons and windows |
| Theme picker | Done | Done | Display Properties |
| Pyxamp face | Done (`platinum`) | Done (`winamp`) | Pyxamp's Winamp face |
| Fleet window (Super+B, Super+O F) | Done | Done | Fleet window above the tray, tray Fleet icon, Properties sheet (see "Fleet window and glance space, Windows 98") |
| Glance space (Super+W) | Done | Done | Shut Down checker, caption animation, Glance taskbar button (same section) |
| Find menu and Go to Address (Super+P, Ctrl+L) | Done | Unthemed card | Run dialog / Find window (not mocked) |
| Window title bars | Done (hyprbars patch) | Missing | Navy caption with minimize, maximize, close (not mocked) |
| Web page styling | Done (`themes/platinum/web.css`) | Missing | `themes/win98/web.css` |
| Session commands with confirmation | Done (Lock, Sleep, Log Out, Restart, Shut Down) | Log Off only | Shut Down Windows dialog (not mocked) |
| About | Done | Missing | System Properties (not mocked) |
| Hide, Hide Others, Show All | Done | Missing | Minimize to the taskbar (not mocked) |
| Window menu (Move to page, Hide, Close) | Done (tile menu) | Missing | Taskbar button right-click menu (not mocked) |
| Held Super+Tab app cycling | Done | Missing (`cycle()` absent) | Alt+Tab Cool Switch box (not mocked) |
| Recent Applications, pinned web apps | Done | Missing | Start ▸ Documents, Favorites (not mocked) |
| Volume and brightness change tag | Done | Missing | Volume pop-up (not mocked) |
| Super+O N (Notifications) | Done | Off | A tray letter for the bell |
| Native apps (GTK, Qt, Ghostty) | Phase 3, not started | Phase 3, not started | Chicago95 for GTK |
| Icons, cursors, pattern, sounds, boot | Phase 4, not started | Phase 4, not started | Win98 counterparts |
| State board, golden images, web drift check | Phase 5, not started | Phase 5, not started | Same checks, both themes |
| Verified on Myoko with real input | Yes (generations 50–52) | No (#13) | — |

## Goal

Simon can switch the whole desktop chrome between a handful of themes: Mac OS 8 Platinum and Windows 98 first, more later. Each theme has its own bars, menus, controls, font and colours. The picker draws itself in the style of the current theme. A switch is live, with no restart and no logout.

## What a theme is

A theme is a set of prefixed QML files plus one entry in a list. Assets and pure policy code live in its folder. Phase 1 tried the original folder-based QML plan and used the specified flat fallback after the dynamic-load spike failed. It is not a palette file. Omarchy's model (one `colors.toml`, rendered into each app's config) cannot express a bevel, a bottom taskbar or a cascading Start menu. Its staging step, the live IPC switch, and the "on-screen apps first" order are still worth copying. See the Omarchy notes at the end.

| A theme decides | Platinum | Windows 98 |
|---|---|---|
| Which bars exist, on which edge | Top menu bar, plus the dock (restyled later) | One bottom taskbar, no dock |
| Where window switching lives | Dock | Taskbar buttons, banded by page |
| Launcher entry | Super+P drops the Find menu from the mountain (the omni service's Platinum view) | Start menu; Run... opens the omni bar's unthemed card |
| Status controls | Bar titles with readouts | Tray icons with tooltips |
| Menu shape and direction | Hangs down from its title | Rises from the tray; Start cascades up and right |
| Components | `Platinum*` set | New Win98 set |
| Font | ChicagoFLF | W95FA |
| Appearances | Light, dark grey, plus Extra dark (black bar) | Light (Windows Standard), dark grey |
| Picker view | Appearance control panel | Display Properties |

Shared by every theme, never forked:
- the data owners: Pipewire, Bluetooth, Wi-Fi, brightness, `OciEgress`, `StorageHealth`, `BuilderGate`, `Notifications`, `Dictation`, `Lanes`, the clock;
- the logic modules and their tests: `MenuState`, `battery.js`, `oci-model.js`, `notification-model.js`, `builder-gate.js`;
- what stays unthemed: the omni bar's service and its card (a theme may draw its own view of the service, see "Find menu" below), notification popups, the dictation overlay, app windows, GTK.

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

The omni service stays one shared owner (`shell.qml`, `context.omniBar`), with its IPC target `omni` (`toggle`, `reveal`, `gotowindow`, `apps`, `navigate`, `dismiss`) and its public rows (`windowRows`, `appRows`, `commandRows`) and `run(row)`. New: `mode` may be `cmd`; `screen` is the focused screen captured on the way in; `enterMode(mode, text?)` and `enterNavigate(text?)`; `back()`, `dismiss()`, `navigateTo(text)`; `claimView(owner)` and `releaseView(owner)` with `themed`. A Desktop that draws its own view claims it while active; the unthemed card shows only while nothing claims it. Win98 claims nothing, so its Super+P, Ctrl+L and Start ▸ Run… keep today's card and look. `omni apps` now opens the Applications scope (it opened All, and the `app` mode was unreachable).

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

Under Platinum every window that leaves its frame to the compositor gets a Mac OS 8 title bar and frame: a close box on the left; a zoom box and a collapse box on the right; pinstripes either side of a plain patch behind the ChicagoFLF title; a black edge and a one-hair bevel round the whole window. An inactive window's bar is flat, with a grey title and no boxes. The bars take the theme's appearance (light, dark grey, black) and follow `desktop-theme` live. Under Win98 there are none, and windows keep the session's edge and corners.

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
| No bar on a client that asked to draw its own frame, or never asked (GTK4/libadwaita, GTK3, a normal Chromium window); decided from the client's own decoration request | The spike's plan was a hand-kept `no_bar` list of libadwaita classes. The request is what the client said, so no list drifts. Cost: such a window has no frame either; normal Chromium windows keep their own tab strip and caption. X11 windows keep stock hyprbars' rule. |
| Collapse hides the focused window (`windows collapseActive`); its app's Show brings it back | Hyprland cannot roll a window up to its title bar (WindowShade). Hiding is the nearest thing that keeps the window. Cost: the window leaves the screen instead of leaving its title bar. The spike made it a float toggle, which matches nothing on Mac OS. |
| A double click on the bar zooms, not collapses | Mac OS 8 shades on a double click; here that would hide the window on a stray double click. |
| Boxes act on press, as stock hyprbars does; no pressed state is drawn | Mac OS acts on release with a sunken box. Not worth the patch size yet. |
| Groups keep Hyprland's tab bar and get no title bar; the tab bar's indicator takes the title colours | As the spike found, two strips stack otherwise. |
| `hl.plugin.load()` on every parse | See `docs/decisions/hyprland.md`. |

### Evidence

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

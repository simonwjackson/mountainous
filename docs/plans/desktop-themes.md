# Desktop themes for Myoko

Status: phase 1 implemented on the a05c2ead base. Written 2026-10-23. No deployment.

Base: `cairn` at `a05c2ead` ("dark grey Platinum bar and an Extra dark toggle"). The later `77dd2791` bevel/shadow change is not included; that line has not landed on `cairn`.

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

`hyprland.lua` today calls `qs -c mountainous ipc call topbar reveal` for the Super+O chord. That name is Platinum's. The `chrome` target now forwards `reveal`, `hide`, and `open <control>` to the active Desktop. `topbar` remains an alias; `chrome toggle` retains the whole-chrome immersive toggle. Win98 maps the same chord letters to its tray icons, and Super alone (or Ctrl+Esc) opens Start.

## Fonts

Phase 1 keeps ChicagoFLF installed and adds no unused font. Phase 2 must install ChicagoFLF and W95FA on Myoko always. Both are small, so a switch never waits for a font. W95FA comes from a `flake = false` input (the mockup prefetched its hash). Its licence file has the template copyright line; record that in the input's comment.

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
| 2 | Win98 theme from the approved mockup and state boards | Win98 selectable |
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

# Desktop themes for Myoko: design draft

Status: phase 1 implementation in progress. Written 2026-10-23.

Base: the newest Platinum branch, `c-c1a4b00c…` at `a05c2ead` ("dark grey Platinum bar and an Extra dark toggle"). Platinum lands on `cairn` first, by someone else. The build starts from `cairn` after that.

## Goal

Simon can switch the whole desktop chrome between a handful of themes: Mac OS 8 Platinum and Windows 98 first, more later. Each theme has its own bars, menus, controls, font and colours. The picker draws itself in the style of the current theme. A switch is live, with no restart and no logout.

## What a theme is

A theme is a folder of QML plus one entry in a list. It is not a palette file. Omarchy's model (one `colors.toml`, rendered into each app's config) cannot express a bevel, a bottom taskbar or a cascading Start menu. Its staging step, the live IPC switch, and the "on-screen apps first" order are still worth copying. See the Omarchy notes at the end.

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
  shell.qml                 data owners per screen, MenuState, IPC, one Loader per screen
  Theme.qml                 mode, extraDark, theme name; tokens for unthemed parts only
  themes.json               canonical IDs, labels, appearances, options and preview paths
  ThemeCatalog.qml          reads themes.json (Nix reads the same JSON)
  ThemeDesktop.qml          two-slot per-screen loader with rollback
  panels/                   data Scopes (today's *Panel.qml minus their `menu` Component)
  themes/platinum/
    Desktop.qml             TopBar + MenuHost (+ dock) for one screen
    menus/SoundMenu.qml …   today's `menu: Component { MenuFrame {…} }` bodies
    Platinum*.qml, PlatinumTokens.qml, PickerView.qml
  themes/win98/
    Desktop.qml             Taskbar + tray host for one screen
    menus/…, Win98*.qml, Win98Tokens.qml, PickerView.qml, StartMenu.qml
```

1. **Data and view split.** Each `*Panel.qml` today holds both its data and a Platinum `menu` Component. The data part stays in `panels/`. The view moves to `themes/<id>/menus/`. A theme's `Desktop.qml` receives the panels and builds its own menu map, as `MenuHost` does now.
2. **Per-screen loader.** `shell.qml` keeps one `Variants` over screens. Inside it, a `Loader` loads `themes/<Theme.name>/Desktop.qml`. Each theme's Desktop owns its windows (layer-shell `PanelWindow`s). The exclusive zone moves with the bar, so Hyprland's usable area follows: top for Platinum, bottom for Win98.
3. **Tokens.** Each theme's components read their own `<Theme>Tokens` singleton, which reads `Theme.dark` and `Theme.extraDark`. `Theme.qml` keeps only the tokens of the unthemed parts. No component ever reads another theme's tokens. A check fails on any cross-theme import.
4. **No `qmldir`.** Verified with this flake's Quickshell 0.3.1 (`gvgrz4bh8hryjzrvkqjiwyh4acpn27aj`): a relative `import "sub"` resolves both a regular component and its sibling `pragma Singleton`, without a `qmldir`. The headless spike printed `SUBFOLDER_SINGLETON_OK`; evidence: `/tmp/themes-p1/spike.log`. Keep subfolders. A partial root `qmldir` still must not be added.
5. **Delivery.** `modules/bars.nix` already walks directories recursively. Phase 1 extends its file filter to JSON and PNG so the canonical registry and thumbnails reach the host. `checks.bar-delivery` explicitly requires nested Desktop and preview files, and rejects development fixture delivery.

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

One shared model in `themes.json`, `ThemeCatalog.qml` and `ThemePicker.qml`: the list of themes, their appearances and options, the current choice, `preview(theme, mode)` and `apply()`. Each theme ships only the view:
- Platinum: the Mac OS 8.5 Appearance control panel. Click applies at once, as on Mac OS 8.
- Win98: Display Properties, Appearance tab. The preview pane changes on selection; OK and Apply commit; Cancel reverts.

Previews of other themes are static images registered in `themes.json` (made by the build's screenshot sweep), so the picker never loads a second theme's QML to draw a thumbnail.

Every theme must open the picker from all of: its own menu (Platinum clock menu, Win98 Start > Settings > Display), the omni bar command "Desktop theme...", and `desktop-theme`. A check enforces that each theme wires all three.

## Keyboard and Hyprland

`hyprland.lua` today calls `qs -c mountainous ipc call topbar reveal` for the Super+O chord. That name is Platinum's. Rename the IPC target to `chrome` (`reveal`, `hide`, `open <control>`), which every Desktop implements. Win98 maps the same chord letters to its tray icons, and Super alone (or Ctrl+Esc) opens Start.

## Fonts

Install ChicagoFLF and W95FA on Myoko always. Both are small, so a switch never waits for a font. W95FA comes from a `flake = false` input (the mockup prefetched its hash). Its licence file has the template copyright line; record that in the input's comment.

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
- Singleton discovery is verified by the phase 1 spike above. No flat-prefix fallback is needed.

## Omarchy notes (verified at omacom/omarchy 967bbdd, v4.0.6)

- A theme is `themes/<name>/` with `colors.toml` (palette plus `mode`), optional `shell.toml` (sizes, border widths, alphas, gradients) and per-app overrides.
- `omarchy-theme-set` stages into `next-theme`, renders `default/themed/*.tpl`, swaps with one `mv`, then sends the palette to the running Quickshell over IPC.
- Apps on screen retint first; the rest retint in the background.
- Light and dark are separate themes; there is no mode switch.
- Taken here: atomic staging, live switch without restart, on-screen first. Not taken: palette-only themes.

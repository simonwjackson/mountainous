# The Layout control

One bar control, in both desktop themes, for the page a screen shows:

- **Arrange**: Tiled or Floating, for the whole page.
- **Windows on this page**: Kamoi capacity, 1 to 3. A window past the cap opens on the next page.
- **Outer gap**: `gaps_out` for the page, 0 to 48 px in 4 px steps, plus Zen margins.

Two scopes, as tabs: **This page** edits the page the screen shows. **Default** edits what a new page on that screen starts with. Each screen has its own default.

Approved mock: `/tmp/layout-mock/` (served at `http://100.114.19.92:8765/layout-mock/index.html`). Screenshots: `/tmp/layout-mock/shots/*.png`, close-ups `crop-*.png`. The mock is the visual spec. The sections below are the behaviour spec and the contract between the parts.

## Decisions

| Question | Choice |
|---|---|
| Gap row on a Floating page | Greyed out, with "Gaps apply to tiled windows." (`general:snap:monitor_gap` is a snapping threshold, not a margin, so the mock's "snap" line is dropped.) |
| Super+F | Toggles the page between Tiled and Floating. The old per-window float toggle moves to Super+Ctrl+F. |
| Gap keys | Super+[ and Super+] step the page's gap by 4 px. |
| Default storage | Per monitor, in `$XDG_STATE_HOME/mountainous/page-layout-defaults.json`, keyed by monitor description (fallback: connector name). |
| Zen | A per-page flag owned by page-layout.lua. `hypr-zen` stays as the command and calls it. Zen does not make a page "differ from default". |

## Parts and owners

```
modules/hyprland/page-layout.lua          backend: all state, rules, keys' Lua side
modules/hyprland/page-layout.test.lua     backend: headless test with a fake hl
modules/hyprland.nix                      backend: install the module, mountainous-page-layout command, hypr-zen, check
modules/hyprland/hyprland.lua             backend: capacity moves into page-layout.lua; binds
modules/quickshell/page-layout-model.js   contract (done): parse the state file, one screen's view
modules/quickshell/panels/PageLayout.qml  contract (done): the per-screen state Scope
modules/quickshell/shell.qml              contract (done): PageLayout per screen, desktopContext.layout
Platinum*.qml, bar-plan.js, themes/platinum/*      Platinum UI
Win98*.qml, themes/win98/*                         Win98 UI
```

## Contract 1: the state file

`$XDG_RUNTIME_DIR/mountainous-page-layout.json`, written atomically (temp file and rename) by page-layout.lua after every change, at load, and when pages are created, removed or renumbered.

```json
{
  "version": 1,
  "fallback": { "cap": 1, "floating": false, "gap": 8 },
  "defaults": { "eDP-1": { "cap": 1, "floating": false, "gap": 8 } },
  "pages": {
    "2": { "monitor": "eDP-1", "cap": 2, "floating": false, "gap": 8, "zen": false, "own": true }
  }
}
```

- `defaults` has one entry per connected monitor, keyed by connector name.
- `pages` has every page with id > 0. `own` is true when cap, floating or gap differs from the monitor's default.
- `page-layout-model.js` parses this; `page-layout-model.test.js` shows the expected cases.

## Contract 2: the command

`mountainous-page-layout`, on PATH in the session. Each call runs one `hyprctl eval` into the live page-layout module and exits non-zero on a bad argument.

| Call | Effect |
|---|---|
| `page <id\|active> [cap=1..3] [floating=true\|false] [gap=0..48] [zen=true\|false]` | Change one page. Any subset of keys. Gap is clamped and rounded to 4. |
| `page-default <id\|active> <cap\|floating\|gap\|all>` | Put one field of a page back to its monitor's default. |
| `default <connector> [cap=..] [floating=..] [gap=..]` | Change a monitor's default and persist it. Existing pages do not change. |
| `reset <connector>` | Every page on that monitor takes the monitor's default (Zen is cleared). |
| `step-gap <id\|active> <delta>` | Gap plus delta, clamped. |
| `toggle-floating <id\|active>` | Flip the page's Arrange. |

`active` means the focused monitor's active page.

## Contract 3: the QML Scope

`desktopContext.layout` on every Desktop is a `PageLayout` (panels/PageLayout.qml). The menu name is `"layout"`: `MenuState.open("layout", screen)`, `qs -c mountainous ipc call chrome open layout`.

| Member | Meaning |
|---|---|
| `available` | The state file is read and the screen shows a page. Hide or disable the control when false. |
| `glyph` | `tile-1`, `tile-2`, `tile-3` or `float`: the bar icon. |
| `tab` | `"page"` or `"default"`; set it from the tabs. Resets to `"page"` on open. |
| `page`, `def` | `{cap, floating, gap}` (page also `zen`, `own`). |
| `shownValues` | The tab's target: `page` or `def`. |
| `shownGap` | The gap to draw (follows a held drag). Set `dragging` while a slider is held. |
| `pageIndex`, `pageCount`, `title`, `ownCount` | "Page 2 of 4 · Built-in Display"; "2 pages differ from this." |
| `capMax`, `gapMax`, `gapStep` | 3, 48, 4. |
| `setArrange(floating)`, `setCap(n)`, `setGap(px)`, `stepGap(dir)` | Act on the tab's target. |
| `toggleZen()`, `useDefault(field)` | This page only. |
| `resetPages()` | Default tab only. |
| `word(n)`, `capNote()` | Shared wording: "Two"; "A third window opens on the next page." |

## Behaviour

- **Capacity** stays the Kamoi cap of hyprland.lua today: tiled windows past the cap move, newest first, to fresh pages at the end of the strip; compaction renumbers pages and the settings follow the page. A page's starting cap is its monitor's default (today a hard-coded 1).
- **Floating page**: every tiled window on it floats, and windows that open on it or move to it float. Capacity is not enforced there. Back to Tiled: windows the page floated tile again (windows a person floated by hand, or pinned, stay floating), then capacity is enforced.
- **Gap**: per page, applied as a workspace rule. Zen on a page replaces its gap with Kamoi's 12% sides and 5% top and bottom of that monitor's logical size.
- **Session restore** keeps working: it shares capacity through page-layout.lua.
- **Keys**: Super+1/2/3 cap, Super+F arrange, Super+Ctrl+F the focused window, Super+[ ] gap, Super+Shift+M zen. All act on the focused monitor's active page.

## UI wording (both themes)

| Element | This page tab | Default tab |
|---|---|---|
| Header | Layout / "Page 2 of 4 · Built-in Display" | Layout / "New pages on Built-in Display" |
| Arrange label | Arrange (Super+F) | Arrange new pages |
| Capacity label | Windows on this page (Super+1 2 3) | Windows per page |
| Capacity note | `capNote()`; plus "New pages start with N." + Use Default when it differs | "Super+1 2 3 change only the current page." |
| Gap label | Outer gap (Super+[ ]) | Outer gap |
| Gap note | "New pages use N px." + Use Default when it differs; "Gaps apply to tiled windows." when floating | none |
| Last row | Zen margins check (Super+Shift+M) | "N pages differ from this." + Reset All (hidden when N is 0) |
| Footer (Platinum) / status bar (Win98) | "Tab this page/default · F float · 1 2 3 windows / ←→ gap · Z zen · Esc close" | same |

Win98 uses "Win+" where Platinum says "Super+", and access keys: &This Page, &Default, &Tiled, &Floating, Use &Default, &Zen margins, &Reset All.

## Validation

Never run `nix flake check`. Build only the checks you touch: `checks.x86_64-linux.bar-model`, the backend's new check, the theme checks you change, and evaluate `nixosConfigurations.myoko.config.system.build.toplevel.drvPath`.

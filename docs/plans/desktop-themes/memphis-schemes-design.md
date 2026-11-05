# Memphis schemes and Drawing Board: the look (design branch)

Branch `feat/memphis-schemes-design`. The binding contract is `/tmp/memphis-schemes/CONTRACT.md`. The parallel build branch owns the state, the registry (`themes.json`), `ThemePicker.qml`, the native themes, the title bars, the web seam and `DesktopPattern.qml`; see its own section.

## What was built

| Part | Files |
|---|---|
| Kit palettes by appearance ID | Hensou `MemphisTokens.qml` (`palette(id)`, 22 IDs), `PlatinumTokens.qml` (`palette(id, extra)`, 3 IDs) |
| Drawing Board drawing | Hensou `PlatinumShadow.qml`, `PlatinumHatch.qml`, `PlatinumCropMarks.qml`; `PlatinumMenuFrame.qml` and `PlatinumDialogFrame.qml` use them |
| Shell surfaces | `PlatinumShadow.qml` and `PlatinumCropMarks.qml` (flat host adapters); `PlatinumWindoid`, `PlatinumCascadeMenu`, `PlatinumFindMenu`, `PlatinumBarHelp`, `PlatinumAboutWindow` and the Appearance panel draw the hatch and the crop marks on Drawing Board |
| Memphis picker | `MemphisPickerView.qml` (appearance IDs), `MemphisPreview.qml` (draws `palette(id)`, now with the scheme's scroll bar), `MemphisComboBox.qml` (a scrolling drop-down list) |
| Platinum picker | `PlatinumPickerView.qml` (appearance IDs; Extra dark only in Dark grey) |
| Art | `themes/platinum/patterns/drawing-board.svg` (original 8 x 8 wave); `themes/memphis/previews/<id>.png` (22) and `themes/platinum/previews/{dark-grey,drawing-board}.png` |
| Renders | `theme-dev/schemes/render.sh`; harness IPC `appearance`, `desktopColour`, `about`, `pickerShow` |

The scheme colours are the XP classic set from the zaxbux gist, verbatim in `MemphisTokens.systemColours`. The kit test `tst_appearances.qml` compares them with the JSON.

## Decisions made without asking

| Decision | Reason / cost |
|---|---|
| Standard and Dark grey keep Hensou's palettes, not "Windows Classic" from the JSON | The contract keeps the five existing appearances. Standard's `li` stays `#dfdfdf`, not the JSON's `#c0c0c0`. |
| A scheme's tokens with no system colour take Standard's (light) or Dark grey's (dark) | Status colours, charts and the icon outline. Dark schemes keep Dark grey's grey icon outline and no emboss. |
| `meter` (progress blocks) is the scheme's Highlight | Memphis drew progress bars in the highlight colour (inferred). |
| The scroll track is solid ScrollBar, except where ControlLightLight equals Window; then the face and light dither | Wine's and ReactOS's default scroll-bar brush (inferred, not checked on Memphis). Standard and Dark grey keep the dither. |
| Menus use Menu and MenuText; the Start band uses the caption text colours | New kit tokens `menu`, `menuText`, `bandText`, `bandSubText`, `windowFrame`, `scrollTrack`, `scrollDither`. Standard and Dark grey keep their old values. |
| Grey text follows the data, also where it is weak | Wheat 1.4:1, Pumpkin 1.6:1 and High Contrast White (`#00ff00` on white) 1.4:1. These are the source values. |
| The drop-down list shows at most 10 rows and scrolls | Memphis lists scrolled. It rises above the field when there is more room there; with no room on either side, its one row lies over the field. It can be wider than the field, up to the window. |
| The pickers accept the old mode API | When the model has no `currentAppearance`, apply and preview take the mode. The branch works before and after the build branch lands. |
| Drawing Board's shadow is hatched, five hairs down and right; the frame lines run five hairs past each corner | Read from the references, redrawn. The About window's surface grows by six hairs on each side on Drawing Board only. |
| Drawing Board's highlight is a blueprint blue `#3a5784` | White has 7.4:1 on it. |

## Drawing Board tokens (kit)

| Token | Value |
|---|---|
| Bar paper (`barSurface`), title paper (`titleSurface`) | `#e8e2d5` |
| Menu and dialog paper (`menuSurface`) | `#f4efe5` |
| Raised, field, list | `#f8f4ec`, `#fefcf8`, `#fefcf8` |
| Well | `#ddd6c8` |
| Frame line (`menuEdge`, `barRule`, `frameLine`) | `#3b3833` |
| Bevel light / dark | `#fdfbf6` / `#bdb5a6` |
| Hatch (`menuShadow`) | `#6f695e` |
| Text / secondary / off | `#24221e` / `#4a463f` / `#8a8477` |
| Highlight / text | `#3a5784` / `#ffffff` |
| Focus ring | `#7d98c4` |
| Desktop | white `#ffffff`, wave `#efebe2` |

## Evidence

Headless sway, Mesa llvmpipe, 2880 x 1800 at scale 1.5, the real shell through the Memphis harness. Kit with a render-only `Theme.appearance` shim and the build branch's ThemePicker API as an overlay (not committed).

- Renders: `/tmp/scheme-renders/memphis/<id>/{window,menu,sound}.png`, `/tmp/scheme-renders/platinum/<id>/{window,menu,clock-menu}.png`, picker ladder `/tmp/scheme-renders/ladder/`.
- Focused checks (Aka, with `--override-input hensou` at the design branch): `checks.desktop-theme-shell`, `checks.memphis-desktop`, `checks.memphis-theme` passed. Kit `tests/run.sh`: 26 passed and 1 skipped without `Theme.appearance`; 27 passed with it.

## Not verified

- On Myoko with real input.
- That the XP classic values equal Memphis's (inferred).
- At 80 px wide, the open scheme list elides names longer than about six letters, and the closed field has no room for its value. The keys and the list still reach every scheme, and the preview draws it.
- Mountainous's `flake.lock` still pins Hensou `0e8a41a`. The shell needs the design kit (`PlatinumShadow`, `PlatinumCropMarks`, `palette(id)`) before it can load.

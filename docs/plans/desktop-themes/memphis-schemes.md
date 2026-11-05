# Memphis schemes and Drawing Board (2026-11-05)

This section supersedes the mode-only registry and state contract above.
There are **25 appearances, 26 native payloads**: 22 Memphis appearances and
three Platinum appearances, plus the retained Platinum Extra dark/OLED payload.
`memphis`, `platinum`, `light` and `dark` remain saved identifiers (ADR 0003).
The five existing payloads retain their palettes, including pure OLED black.
The existing public theme labels stay unchanged.

### Registry, state and picker interface

- `themes.json` declares `{id, mode, label, thumbnail}` for every appearance.
  Thumbnail paths are `themes/<theme>/previews/<appearance-id>.png`.
- `theme-appearance` adds the saved appearance ID beside `theme-name`, `theme`
  (derived mode), `theme-extra` and `theme-sounds`. `desktop-theme` remains the
  only writer, under its existing lock. This is one current-theme choice, not
  a per-theme map. Switching themes falls back if the saved ID is not valid
  for the target theme.
- A missing key resolves from the old mode: Memphis light becomes `standard`,
  Platinum light becomes `light`, and dark becomes `dark-grey` in either theme.
  The next successful write creates the missing key. Reads do not create files.
- An unknown ID resolves to the mode default without replacing the saved ID.
  `reapply`, Extra dark and theme switches keep it. An explicit appearance or
  mode choice replaces it. Known appearances always derive mode; a contradictory
  old mode cannot override them.
- Dark IDs: `dark-grey`, `high-contrast-black`, `high-contrast-1`,
  `high-contrast-2`. All other IDs are light. Extra dark is retained but ignored
  by Memphis and by Platinum Light/Drawing Board.
- `desktop-theme apply <theme> <appearance-id> <on|off>` commits a choice.
  Existing `light`/`dark` arguments remain aliases for the mode defaults.
  The output/status format stays compatible with existing consumers.
- `ThemeCatalog.appearance(theme, id)`, `ThemePicker.currentAppearance`,
  `preview(theme, appearanceId)` and `apply(theme, appearanceId, extra)` use IDs.
  Picker choices expose `appearanceId` and the existing `appearance` label.
  The Memphis view owns draft/Apply/Cancel behaviour; it does not write state.
- Hensou's Qt adapter and the Quickshell host read the same key and derive
  mode before publishing kit state. Kit `Theme.appearance === ""` supports
  mode-only hosts. `dark` and `extraDark` keep their existing meanings.

### One colour source and generated outputs

`scripts/xp-classic-schemes.json` is a byte-for-byte copy of the supplied XP
classic table from zaxbux's **Windows System Colours (by OS)** gist. SHA256:
`a7f330d2e3ccc077a98ef220f86e3aee8c19be488c93c569bb81cbbfee59d406`.
The copy was compared to `/tmp/memphis-schemes/xp-classic-schemes.json` when added;
`tests/system-palettes.py` pins that digest. Brick matches ReactOS
`boot/bootdata/hivedef.inf`; equality to Memphis remains **inferred**, not verified.
No new Memphis colour was selected from memory. Existing Standard and Dark grey
palettes take precedence over the table's two Classic entries to prevent a
regression of the five existing payloads.

`scripts/generate-native-themes.py` maps system roles once, then generates
GTK2, GTK3, GTK4, Qt5/Qt6 palettes, Kvantum (Platinum), Ghostty and per-payload
web token CSS. It also regenerates the shell's web token sections and the Lua
system-palette block, with:

```sh
python3 scripts/generate-native-themes.py \
  --schemes scripts/xp-classic-schemes.json --update-shell modules/quickshell
```

GTK/Qt fields use Window/WindowText, selections use Highlight/HighlightText,
menus use Menu/MenuText, and tooltips use Info/InfoText. Native geometry remains
upstream geometry. GTK2 gets a generated RC include while preserving unrelated
user configuration. Existing toolkit restart boundaries still apply.

Title bars use ActiveCaption → GradientActiveCaption and InactiveCaption →
GradientInactiveCaption with their corresponding text colours. The Lua data
is generated, not hand-copied. No plugin ABI or login boundary changes.

### Drawing Board native palette

The native, web and title-bar values come from `PlatinumTokens.palette("drawing-board")`
in the Hensou kit, which is the single visual source. They are not sampled Apple
artwork. Structure, fonts and metrics stay Platinum's.

| Role | Platinum Light native | Drawing Board native | Kit token |
|---|---|---|---|
| Face (bar, title, window) | `#dddddd` | `#e8e2d5` | `barSurface`, `titleSurface` |
| Text | `#000000` | `#24221e` | `barText`, `menuText` |
| Field/base paper | `#ffffff` | `#fefcf8` | `field`, `list` |
| Highlight edge | `#ffffff` | `#fdfbf6` | `bevelLight` |
| Shadow | `#999999` | `#bdb5a6` | `bevelDark` |
| Graphite frame | `#000000` | `#3b3833` | `frameLine`, `barRule` |
| Selection | `#333399` | `#3a5784` | `highlight` |
| Disabled text | `#8a8a8a` | `#8a8477` | `barTextOff`, `menuTextOff` |

The Drawing Board title bar uses face `#e8e2d5`, title `#24221e`, inactive title
`#8a8477`, frame/rule `#3b3833`, and boxes `#fefcf8`. Its stripe/bevel pair both
use the face colour, so the existing plugin draws a plain paper title bar.
Extra dark does not change this light-only appearance.

### Asset staging and parity ledger

The appearance ID selects web palettes and optional desktop tiles. The registry
contains only files which exist. Standard and Dark grey keep the existing
Memphis `light.svg` and `dark.svg` tiles unchanged. All 20 new Memphis schemes
have no tile: the shared desktop paints `MemphisTokens.palette(id).desktop`, the
JSON Desktop system colour. There is no mode-tile fallback for these schemes.
Drawing Board keeps design's `themes/platinum/patterns/drawing-board.svg`.
Thumbnail compatibility remains separate from this strict pattern-path check.

| Surface | Build-owned implementation | Proof |
|---|---|---|
| Registry/picker model | 25 ID-based entries; old mode API aliases | Catalog/model and migration checks |
| State and kit host adapter | One `theme-appearance` key; derived mode; unknown IDs preserved | Rust state tests and CLI migration cases |
| GTK2/3/4, Qt5/6, Ghostty | 26 generated payloads | `checks.native-themes`; real Qt engines and Ghostty config validator |
| Web controls | Generated palette blocks and appearance-aware selection | Focused web policy tests |
| Compositor captions | 20 generated system palettes, legacy ramps and Drawing Board | `checks.titlebars` and source-digest/role checks |
| Bar/taskbar, menus/dialogs and previews | Design worker's kit tokens/components/views | Combined kit and headless sweep (design/integrator) |
| Desktop pattern and thumbnails | Optional real tiles or solid Desktop colour; design worker owns SVG/PNG files | Combined asset review (design/integrator) |

No aggregate flake checks are permitted. Focused proof runs on Aka through
`/tmp/memphis-schemes/heavy.sh`, which takes `/tmp/platinum-heavy.lock`.
Final logs and remaining gaps are recorded below after validation.

### Build-worker proof on Aka

All runs below used the shared heavy lock. Nix used no remote builders, one job
and four cores. Mountainous checks used an explicit local Hensou input override
containing the new kit property; the repository lock file was not rewritten.

| Check / actual path | Result | Aka log under `/tmp/memphis-schemes/build/logs/` |
|---|---|---|
| `cargo test -p hensou-theme-state` | 6 passed, including real old-state files and unknown-ID preservation | `hensou-host-kit-2.log` |
| `cargo clippy -p hensou-qt-host -- -D warnings` | Passed; the generated Rust/Qt property boundary compiled | `hensou-host-kit-2.log` |
| Rustfmt and `bash kit/qml/Hensou/tests/run.sh` | 17 passed, 0 failed | `kit-3.log` |
| `checks.desktop-theme` / `scripts/test-desktop-theme` | Passed; old-file migration, unknown IDs, aliases, Extra dark, recovery and bus failures | `desktop-theme-final.log` |
| `checks.native-themes` | Passed; 26 payloads, all 25 choices applied through the real CLI, 108 real Qt5/Qt6 probes; all Ghostty configs validated | `native-themes-1.log` |
| `checks.titlebars` | Passed; existing plugin binary contract, legacy palettes, 20 source gradient pairs and Drawing Board | `titlebars-1.log` |
| `checks.theme-appearance-host` | Passed; actual offscreen Quickshell watched all 25 choices, returned their picker previews, derived contradictory modes, and retained unknown IDs | `appearance-host-1.log` |
| Ruff, Python compilation, focused ShellCheck/Bash syntax, Nixfmt, source digest/roles, catalog, pattern and web policy checks | Passed | `static-3.log` |

The first kit invocation returned 126 because the runner is not executable in
the snapshot. Running it through Bash passed. The Rust steps before that failure
had passed. The first static runs found formatting, an explicit-subprocess-check
lint and a shell string warning; the final static run is clean.

The native checks inspect GTK2/3/4 outputs and execute both Qt engines. They are
not native-application visual captures. Design's token/component/asset merge,
Drawing Board palette reconciliation and the combined headless render ladder
remain the integrator's work. No live user state, compositor or device was
changed; no deployment is claimed by these checks.

### Integration seam correction (2026-11-05)

The first merged check failed because the native and caption tests parsed the
old spelling of QML colour properties. The merged kit now delegates those
properties to `palette(id, extra)`. The first build-worker proof used its own
unmerged kit and did not expose this failure.

`lib/kit-palettes.nix` now runs `tests/tst_kit_palettes.qml` in the real headless
Qt test runner. It exports both Extra dark states of all 25 public appearances.
The native check compares all 26 generated payloads to these evaluated colour
roles. The caption check compares all 25 appearances with Extra dark off and on.
Neither check parses kit token source text. The extra QtTest dependency is
check-only; installed native themes and the compositor gain no dependency.

The semantic adapters keep existing native policy explicit: the two legacy
Memphis native ramps use their existing inner highlight and field ink, and
Platinum OLED native surfaces keep their black wells and existing disabled ramp.
Drawing Board native/caption paper takes `titleSurface`, not the deliberately
lighter `menuSurface`. This does not change the colours reconciled in da6441bc.

The Kvantum `FileExistsError` in the native log is an expected, injected private
HOME directory collision. The rollback test checks that native synchronization
refuses to replace it, preserves the recovered state, then repairs the derived
files after the collision is removed. `NATIVE_THEME_TESTS_PASSED` follows it;
the exception is not the integration failure.

Verified on Aka, under the shared heavy lock, against merged Hensou `42b3df9`
(`path:/tmp/memphis-schemes/review/hensou`). The Mountainous source was the merged
`df488771` snapshot with da6441bc and this seam correction overlaid. No kit token
files were changed. No aggregate checks ran.

| Focused check | Result | Aka log |
|---|---|---|
| `checks.native-themes` | Passed: 26 native payloads compared to evaluated kit palettes; native runtime/asset checks retained | `/tmp/memphis-schemes/build/logs/seam-native-1.log` |
| `checks.titlebars` | Passed: actual evaluated colours for every appearance and both Extra dark states | `/tmp/memphis-schemes/build/logs/seam-titlebars-1.log` (execution); `seam-titlebars-final.log` (final cache confirmation in the same directory) |
| Ruff, Python compilation, focused Nixfmt | Passed | `/tmp/memphis-schemes/build/logs/seam-style.log` |

### Review round 1 corrections

- Removed all nonexistent tile registrations. Pattern checks now require every
  registered path to exist, and pin the two original Memphis tile hashes.
- The shared desktop paints each tile-less Memphis scheme's actual kit Desktop
  colour. The focused check compares all 20 colours to the JSON source.
- New web schemes use the kit's solid ScrollBar or face/light-edge checker
  policy, and ControlLightLight for dither. Legacy light/dark token blocks stay
  byte-for-byte unchanged; shared CSS defaults preserve their existing checker.
- `ThemeCatalog.resolveAppearance(theme, id, mode)` returns the valid registry
  entry or the mode's default entry (null for an unknown theme). It accepts only
  stable IDs; the separate picker `appearance()` API retains old mode aliases.
  Theme.qml uses this resolver. Standalone galleries use the kit's empty-ID,
  mode-only contract rather than another copy of the fallback IDs.
- Implementation and evidence now live here, under the plan's required folder.

Focused checks ran on Aka under `/tmp/platinum-heavy.lock`, against the merged
kit and design assets. No full suite or aggregate checks ran. The lock file was
not updated. A new headless surface check loads the actual `DesktopPattern.qml`
under a private labwc, uses the software renderer and headless backend, and reads
compositor screenshots with grim. All 20 schemes matched their JSON Desktop
pixel values, including Brick `(66, 0, 0)` and High Contrast White `(255, 255, 255)`.
Both legacy Memphis tile hashes and both legacy web token-block hashes are pinned.

| Focused check | Result | Log under `/tmp/memphis-schemes/build/logs/` |
|---|---|---|
| Strict pattern check before the fix | Failed on the registered nonexistent `platinum/patterns/dark-grey.svg`, reproducing the review | `round1-repro.log` |
| `checks.desktop-appearances` | Passed: all registered tiles exist; 20 desktop colours equal JSON; web tracks/dither equal evaluated kit tokens; legacy hashes unchanged | `round1-desktop-final.log` |
| `checks.desktop-appearance-surface` | Passed: actual desktop surface and compositor pixels for all 20 schemes, plus live state/preview/resolver cases | `round1-surface-final.log` |
| `checks.theme-appearance-host` | Passed: 25 live choices, resolver valid/unknown IDs and mode defaults | `round1-host.log` |
| Ruff, Python compilation, ShellCheck/Bash syntax, focused Nixfmt, registry positive/negative checks and plan location | Passed | `round1-style-final.log` |

# Fleet window and the glance space

Status: built on `cairn` at `37c91c12`; not deployed. Written 2026-10-24. The Windows 98 form: `docs/plans/desktop-themes.md`, "Fleet window and glance space, Windows 98".

Spec: the approved mocks, `/tmp/hud-mock/` (Fleet windoid) and `/tmp/glance-mock/` (glance space; `DIRECTION.md` has the tokens and the mock's motion table). Data contract: `~/.local/share/mountainous/handoffs/beszel-quickshell-hud.md`. Simon's decision after the mocks: the bar's Fleet readout is the title of the Glance menu; the Application menu is not swapped.

## What exists

| Part | Files |
|---|---|
| Data owner, one per shell | `panels/Beszel.qml`: states `loading`, `ready`, `unavailable`, `error`; a failed refresh keeps the last good sample (`failing`, `stale`); about 7 minutes of samples per host for the five-minute CPU/memory rule; the shared view state (`sort`, `selected`, `expanded`); the drill-down for the expanded host only |
| Helper (read-only) | `beszel-status` prints the systems; `beszel-status host <name>` prints `{system, metrics, failed, smart}` from `get_system_metrics` (1 h, 30 points), `list_services` (Failed) and `list_smart_devices` (that host only, without serials). The token stays on fd 3; names are validated and only ever travel as jq strings |
| Model | `beszel-model.js`: `hostTone`/`fleetTone` unchanged; new `hostView`/`fleetView` (the reasons behind each tone), formats, `sortHosts`, `summaryVariants`, `barReadout`, `trimHistory`, `parseDetail`, `series` |
| Layout policies | `fleet-plan.js` (the mock's `hudPlan`: nine width levels, row height, summary in the title, scroll bar); `glance-plan.js` (Clean Up layout, remembered places, zoom-rect frames); `glance-registry.js` (the widgets and the saved state) |
| Shared state | `GlanceState.qml` singleton: which screen shows the space and the Fleet window, the zoom origin, `$XDG_STATE_HOME/mountainous/glance.json`, reduced motion |
| Views (Platinum) | `PlatinumFleetView`, `PlatinumFleetRow`, `PlatinumFleetDetail`, `PlatinumWindoid`, `PlatinumFleetWindow` (standalone), `PlatinumGlanceSpace`, `PlatinumDisksWidget`, `PlatinumGlanceMenu`, `PlatinumFleetGlance` (one screen's controller), primitives `PlatinumStatusLight`, `PlatinumProgressBar`, `PlatinumSparkline`, `PlatinumPattern`, `PlatinumBarberPole`, tokens `PlatinumGlanceTokens` |
| Shared-file edits (additive) | `shell.qml` (the `Beszel` owner, `context.beszel`, IPC `fleet` and `glance`), `PlatinumDesktop.qml` (one controller, four forwarding methods, the `fleet` menu), `PlatinumTopBar.qml` (the `fleet` control, its metrics, `controlRect`, the chord hint), `PlatinumOverflowMenu.qml` (its label), `bar-plan.js` (`fleet` after `disk`), `hyprland.lua` (Super+B, Super+W, Super+O F), `beszel-desktop.nix` (`checks.fleet-glance-model`) |

## Keys and IPC

| Key | IPC | Platinum | Win98 |
|---|---|---|---|
| Super+B, Super+O then F | `qs -c mountainous ipc call fleet toggle` | Toggles the Fleet window. From the glance space it dismisses the space and opens the window. | The same, for the Win98 Fleet window above the tray; a minimized window comes back |
| Super+W | `glance toggle` (also `reveal`, `hide`) | Toggles the glance space on the focused screen | The same, for the Win98 glance space |
| Super+O, then the chord | `chrome open fleet` | Opens the Glance menu | Toggles the Fleet window (the tray Fleet icon's action) |

Super+W and Super+B were free in `hyprland.lua` (checked against every `hl.bind`). Kanata (`modules/kanata.nix`) leaves physical W alone; physical B is dead (f24) and physical `.` types `b`, so Super+B is held Space + `.` on Simon's keyboard. Escape in the space is the `kl` chord (Escape is dead on the base layer).

## Glance space motion

All rows answer a key or a click, so they are focus travel (under 250 ms). No alpha in any frame: each frame is presence only (the background, whole widgets, hair outlines).

| Element | Kind | Trigger | Property | From → to | Start | Duration | Easing |
|---|---|---|---|---|---|---|---|
| Background | Focus travel | Super+W, menu item | presence | absent → present | 0 ms | 0 (cut) | none |
| Zoom outlines, summon | Focus travel | same | 4 trailing outline rects per widget | the origin (the Fleet readout, or the menu row clicked) → each widget's rect | 0 ms | 150 ms (frames 0–8) | `p = 1 − (1 − k/9)²`, one step per 60 Hz frame |
| Widgets, summon | Focus travel | same | presence | absent → present, all at once | 150 ms (frame 9) | 0 (cut) | none |
| Input, dismiss | Focus travel | Super+W, Esc, a background click, Hide Glance | input mask, focus grab | the space → the work | 0 ms | 0 | none |
| Widgets, dismiss | Focus travel | same | presence | present → absent | 0 ms | 0 | none |
| Zoom outlines, dismiss (the mirror) | Focus travel | same | 4 trailing outline rects | each widget's rect → the origin | 0 ms | 150 ms | `p = 1 − (k/9)²` |
| Background, dismiss | Focus travel | same | presence | present → absent | 150 ms (frame 9) | 0 (cut) | none |
| Reduced motion | | `$XDG_STATE_HOME/mountainous/reduced-motion` is `on` | every row | end state at frame 0 | 0 | 0 | |
| Barber pole (loading) | Idle | Fleet loading | stripe offset | 0 → one tile, looped | 0 | 600 ms | linear; stops under reduced motion |

`glance-plan.js` `frameAt(style, dir, t, reduced)` is the function of time; `PlatinumGlanceSpace` evaluates it on each `FrameAnimation` tick from the key's time, so a late frame drops a step and never stretches the move.

## Decisions made beyond the brief

See the report in `/tmp/fleet-glance/REPORT.md` for evidence. Short list:

| Decision | Why / cost |
|---|---|
| The space is a Top-layer surface, not Overlay | The brief says "overlay layer surface". Hyprland stacks surfaces of one layer in map order, so the space (mapped on summon) covers the bar's shadow, the dock and an open Fleet window, while the bar's menus (mapped later) draw over it. On the Overlay layer the Glance menu would open under the dither. Cost: a fullscreen window covers Top-layer surfaces in Hyprland, so Super+W over a fullscreen window is not proven to show the space. |
| The space covers the whole screen with an input mask that leaves out the bar | As `PlatinumMenuHost` does: the bar stays live, and the zoom rects can start at the readout in the bar. |
| The bar readout counts as a Fleet view | It needs a current count; so Beszel polls every 60 s while the Platinum bar shows, not only while a window is open. Under Win98 nothing polls. |
| A failed SMART disk raises a host's tone only after its drill-down ran | The brief keeps `list_smart_devices` to the expanded host. Fetched verdicts are kept for the session. |
| Fleet-level staleness is per host | A failed refresh keeps the last sample; each host passes the model's three-minute warning on its own, and a sunken "Last update" badge and the footer say so. |
| Sizes snapped to even logical pixels | 19-px column headers and rows and the 15-px footer became 20, 20 and 16, so every hair lands on whole device pixels at 1.5. |
| Dark grey dither: black ink, the other cells clear | The mock's token table; "#000 on #363636" is what it gives over the bar-grey surfaces. `PlatinumGlanceTokens.ditherGround` makes an opaque #363636 ground a one-line change. |
| Widget checks are check boxes inside selectable menu rows | They keep keyboard selection (Up, Down, Return) like the other menu rows. |
| The glance Fleet has no grow box | Its size is the plan's; the standalone window keeps its grow box. |

## Evidence and limits

Nested Hyprland 0.56.2 in headless labwc at 2880×1800, scale 1.5 (`/tmp/fleet-glance/`, `REPORT.md`). Measured there: summon ends at frame 9 (152–157 ms after the call), dismiss at 161–162 ms, reduced motion draws no animation frame; the dither's ink cells are 100% pure black on the screen's 3-device-px checker; the Glance menu draws over the space; a Win98 swap leaves only the taskbar mapped and the Fleet/glance IPC does nothing there. Focused checks `beszel-model`, `beszel-status`, `fleet-glance-model`, `bar-model`, `bar-delivery`, `desktop-theme`, `desktop-theme-shell` and `win98-desktop` pass; the Myoko toplevel evaluates.

Not proven: Super+W and Super+B as real key presses (the binds load; a virtual Super from wtype did not fire them), the dither on Myoko's OLED, the space over a fullscreen window, two screens.

Review tools: `qs -c mountainous ipc call glance seek <ms> in|out` holds one frame (`-1` runs again), `glance slow <n>` plays the motion n times slower, and `MOUNTAINOUS_GLANCE_TRACE=1` logs each frame.

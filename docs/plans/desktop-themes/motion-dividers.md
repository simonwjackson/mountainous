# Plain page dividers, and motion true to each OS (implemented)

Open items 2 and 3 from Simon's use on Myoko (2026-10-28). Both themes.

Simon: "I asked to get rid of the numbers for the workspaces. I took it too literally… I'm talking about the whole button. Now there's just this weird empty space at the beginning of each segment of the taskbar." And: "The fade in and out effects kind of ruin the effect. It doesn't feel like Windows. If they used an animation, we should use that animation rather than a soft fade."

This section supersedes the "page band's head is one flat click target" row in "Windows 98 taskbar and session parity".

## 1. Page dividers are a plain divider

| | Before | Now |
|---|---|---|
| Win98 taskbar, between two pages | Etch, grip and a 16-u flat head button (hover, press, focus ring, tooltip naming the page's apps, a click showed the page); 32 u before the first button | Win98's etched toolbar groove only: 2 u (a dark line and a white line), 3 u of gap each side. No hit target, hover, tooltip, focus stop or slot |
| Win98 taskbar, before the first page | The same head | Nothing: the first button stands 3 u after Start, as in Win98 |
| Win98 taskbar, no windows | An empty band's etch and grip | Nothing |
| Platinum Control Strip | Already the engraved groove between pages (`strip-plan.js` `GROOVE`), no head | Unchanged |

Switching pages without the head:

| Path | Status |
|---|---|
| A click on a window button | Unchanged: it focuses the window, and its page comes with it |
| Start ▸ Windows | Unchanged: it lists every window (a separator between pages) and activates the chosen one |
| Keyboard on the taskbar (Esc from a keyboard Start menu, then Left/Right/Tab) | The order is Start, the window buttons, the chevrons, the tray, the clock. The page stops are gone; nothing else moved |
| Super+Page_Up / Page_Down, and Super+H/J/K/L focus (which crosses pages) | Unchanged (compositor binds in `hyprland.lua`) |
| Drag and drop | A drop onto a page's window buttons still moves the window to that page (`shell.dropOnto`), so the drop onto a divider is not needed. Dropping on a divider does nothing, as before |

Code: `themes/win98/taskbar-plan.js` (`TAG` gone, `SEP = 2`; each group carries `divider` and `head`; a page costs 5 u, not 31), `Win98Taskbar.qml` (bands draw only the `Etch` on `divider`; `dividers()` for the checks), `Win98MenuHost.qml` (no `page` focus stop), `Win98Desktop.qml` (`showPage`, `bandNames` and the page tooltip removed; `debugPlaces()` adds `dividers` and `focusOrder`).

The freed width goes to the window buttons: 22 windows on 6 pages at 1440 u now keep 47-u buttons with titles (they were icons only).

## 2. No soft fades: motion true to each OS

### Audit

Every fade or opacity animation in both themes, and what it is now.

| Where | Before | Win98 now | Platinum now |
|---|---|---|---|
| Hyprland `windows` (open popin, close, move) | speed 4, `quick` curve | Off: a window appears and goes at once | Off |
| Hyprland `fade` (fadeIn/Out, fadeSwitch, fadeDim, fadePopups, fadeLayers, fadeDpms) | speed 4, `quick` | Off | Off |
| Hyprland `layers` (layersIn/Out: every Quickshell surface: menus, tray windows, dialogs, tooltips, the Fleet window, the glance space, notifications, the dictation overlay) | Hyprland's default (on, speed 8) | Off: every layer surface maps at once | Off |
| Hyprland `workspaces` (page slide, the terminal overlay's special workspace) | speed 4, `quick` | Unchanged (a slide, not a fade; neither OS had pages) | Unchanged |
| Win98 menus (`Win98MenuPanel` reveal, 120 ms roll) | Roll | Unchanged: the roll | — |
| Platinum menus | No QML motion; the layer fade made them fade | — | At once (the layer fade is off) |
| Win98 tooltips (`Win98TipWindow`), Platinum Balloon Help | No QML motion; the layer fade | At once | At once |
| Win98 dialogs and tray windows, Platinum windoids | No QML motion; the layer fade | At once | At once |
| Notification pop-ups (`NotificationPopups`: `NumberAnimation on remaining`) | A countdown bar, not a fade | Unchanged; the pop-up maps at once | Same |
| Fleet window and glance space | Caption animation (Win98), zoom rects (Platinum), no alpha; plus the layer fade | The caption animation only | The zoom rects only |
| Control Strip scroll (`Behavior on x`, 120 ms, off under reduced motion) | A slide of the track | — | Unchanged (focus travel, not a fade) |
| Barber pole (`PlatinumBarberPole`) | Idle stripe, stops under reduced motion | — | Unchanged |
| Taskbar drag ghost (0.85) and dragged button (0.4) | Static opacity, no animation | Unchanged | — |

No QML `Behavior on opacity` or opacity `NumberAnimation` exists in either theme; every soft fade was Hyprland's.

### What each theme draws

| Event | Windows 98 | Mac OS 8 (Platinum) |
|---|---|---|
| Minimize (Win98) / collapse box, Hide, Hide Others (Platinum) | The caption animation: the window goes at once, its caption bar (title, active or inactive gradient) flies to its taskbar button | Zoom rects: the window goes at once, four trailing outlines shrink into its Control Strip tile |
| Restore / Show | The caption flies from the button to the window's place; the window appears when it lands | Zoom rects grow from the tile (or where it was) to the window; the window appears when they land |
| Maximize and restore (caption button, double click, window menu, keys) | The caption flies from the old caption to the new one | None: the zoom box cuts |
| Open | None: a window appears at once | Zoom rects from its tile to the window |
| Close | None | Zoom rects from the window into its tile |
| Menus | The 120 ms roll | At once |
| Tooltips, dialogs | At once | At once |
| Reduced motion | Every move is the cut | Same |

Timing for every move: 150 ms, frames 0 to 8 at 60 Hz, the glance space's frames and curves (ease out toward the window, ease in toward the control). The glance space's own last frame stops a fifth of the way from its origin; a window's move is spread over frames 0 to 8 so frame 8 lands on its end. No alpha in any frame.

Motion spec, per move:

| Element | Kind | Trigger | Property | From → to | Start | Duration | Easing |
|---|---|---|---|---|---|---|---|
| Win98 caption bar | Focus travel | Minimize | Rect | Window caption → taskbar button | First frame | 150 ms (9 frames) | Ease in (1 − s²) |
| Win98 caption bar | Focus travel | Restore | Rect | Button → window caption | First frame | 150 ms | Ease out (1 − (1 − s)²) |
| Win98 caption bar | Focus travel | Maximize, restore | Rect | Old caption → new caption | Next refresh after Hyprland's `fullscreen` event | 150 ms | Ease out |
| Platinum zoom rects (4 trailing, 1 hair white and 1 hair black) | Focus travel | Open, Show | Rect | Tile → window frame | First frame | 150 ms | Ease out |
| Platinum zoom rects | Focus travel | Close, collapse, Hide | Rect | Window frame → tile | First frame | 150 ms | Ease in |

### Implementation

| Piece | File |
|---|---|
| Hyprland per-theme motion, live on every `desktop-theme` change (the same `t.apply()` the title bars use): `windows`, `fade` and `layers` off under both themes; the session's values back for any other theme. It applies with or without the hyprbars plugin | `modules/hyprland/titlebars.lua` (`MOTION_LEAVES`, `SESSION_MOTION`, `motion(state)`, `apply_motion()`); `hyprland.lua` comment |
| The pure table, the events from a hide/show batch and a maximize, the frames | `modules/quickshell/window-motion.js` (+ `window-motion.test.js`) |
| The shared event owner: WindowHider's batches (new `moving` signal, before the batch runs), Hyprland's `openwindow`, `closewindow`, `fullscreen` (shell.qml forwards its raw events); `requested(e)`; review IPC `motion seek <ms>`, `motion slow <n>`, `motion current` | `WindowMotion.qml`; `shell.qml` (rows gain `w`, `h`, `fullscreen`, `active`) |
| Restore waits for its motion: a show batch runs `revealDelay` (150 ms, 0 under reduced motion or another theme) after the request; a later batch flushes a waiting one first, so order is kept | `WindowHider.qml` (`showDelay`) |
| The overlay: one per screen per Desktop, layer `Overlay`, namespace `mountainous-motion`, no input, mapped only while a move runs | `MotionLayer.qml` |
| Win98's caption animation (ends: the window's lane button, then the windows chevron, then Start) | `Win98MotionLayer.qml`, in `Win98Desktop.qml` |
| The Finder's zoom rects (ends: the window's tile, `PlatinumControlStrip.tiles`; a closed window's tile from the snapshot before; a hidden one's kept from its hide; else the strip's `tail`) | `PlatinumMotionLayer.qml`, in `PlatinumDesktop.qml`; `PlatinumControlStrip.qml` (`tiles`, `tail`) |

Theme switching does not animate: Hyprland's motion is off under both themes, and no event comes from a switch or a Quickshell restart (WindowMotion takes its first snapshot without events, and a maximize is only seen as a change between two snapshots). The motion surface is unmapped at rest, so `switch.sh`'s mapped-surface lists are unchanged.

## Decisions made without asking

| Decision | Why | Cost |
|---|---|---|
| Page slides (Hyprland `workspaces`) keep the session's slide under both themes | Not a fade; neither OS had pages; the slide says which way the page went | It is still motion neither OS had. One line in `titlebars.lua` (`MOTION_LEAVES`) cuts it |
| Hyprland `windows` off, so tiling reflow cuts too | A window moving while its caption flies would draw two motions; Win98 and Mac OS 8 had no animated reflow | Tiling changes (a new window, a swap) jump instead of sliding |
| The first page has no divider; a divider stands only between two pages | Win98 had no separator between Start and the task buttons | Nothing marks where the first page starts except Start |
| Restore waits 150 ms before its window moves | Win98 and the Finder drew the animation, then the window | 150 ms more latency on restore and Show; a Quickshell restart inside those 150 ms leaves the window hidden (reconcile adopts it; Show still works) |
| Platinum zooms every hide (Hide, Hide Others), not only the collapse box | One rule: a hidden window goes into its tile | Hide Others with many windows draws many zooms at once |
| Platinum open and close zoom from and to the window's Control Strip tile | The tile is the window's icon on this desktop; the Finder zoomed from the icon | A real Mac OS 8 app's windows (not the Finder's) had no zoom |
| Fullscreen (state 2) has no caption motion; only maximize (1) does | Win98 had no fullscreen | — |

## Evidence

Served at http://100.114.19.92:8765/tandem/motion-dividers/ (`/tmp/tandem/motion-dividers/`).

| What | Files |
|---|---|
| Filmstrips, Win98, light and dark grey: minimize, restore, maximize, unmaximize, close (a cut), minimize under reduced motion (a cut) | `win98-{light,dark}-{minimize,restore,maximize,unmaximize,close-cut,minimize-reduced}.filmstrip.png` |
| Filmstrips, Platinum, light and dark grey: open, close, collapse, show, zoom box (a cut) | `platinum-{light,dark}-{open,close,collapse,show,zoom-cut}.filmstrip.png` |
| The dividers: 1920 × 1200 normal and many pages, keyboard focus, light and dark grey; 720 × 900; the Control Strip's grooves | `dividers/` |

Each filmstrip is eleven cells: before, frames 0 to 8 (0 to 133 ms, held with the harness's motion hold), after. They come from the real Desktops' motion layers in the Win98 harness (`theme-dev/win98/capture-motion.sh`, headless sway, pixman, llvmpipe), with a stand-in app window under the chrome; the harness sends the events WindowMotion would.

## Checks

Run on Unzen (`/tmp/tandem/remote-check.sh`), on the branch rebased onto `cairn` at dd716cdf (code commit 8220bcb8):

| Check | Result |
|---|---|
| `titlebars` (motion per theme, apply with and without the plugin, a rejected leaf, `hyprland.lua`'s values) | pass |
| `theme-parity` (with `no-page-numbers.test.js`: no page head, dividers are a groove) | pass |
| `platinum-desktop` (with `window-motion.test.js`), `bar-delivery` (the new files delivered, the test not) | pass |
| `win98-desktop` (`taskbar-plan.test.js`; `switch.sh` 20 swaps; `geometry.sh`: dividers inside the task area, never over a button, no page place) | pass |
| `win98-taskbar` (two dividers between three pages, each a groove in the gap; no head, no keyboard stop; no page number) | pass (one earlier run failed "(Empty) is shown" in Documents, untouched by this work; the re-run passed) |
| `win98-theme`, `win98-fleet`, `desktop-theme-shell` (restart and rollback), `desktop-safety`, `bar-shadow` | pass |
| The Myoko toplevel `drvPath` | evaluates |

The minimize and restore sounds (phase 4) still play when the request is made, so a sound starts with its motion.

## Not verified

- On Myoko under Hyprland: the live `hl.animation` calls through `hyprctl eval`, the first frame's alignment with the real hyprbars caption (the code puts the caption one seam above Hyprland's `at`), and a maximize's event-to-refresh latency. The harness has no Hyprland.
- A Platinum open: the window appears at once (Hyprland cannot hold it back), so the zoom rects draw over the new window for 150 ms instead of before it.
- The motion surface maps when a move starts; a slow first frame is absorbed (the clock starts on the first frame), not measured.

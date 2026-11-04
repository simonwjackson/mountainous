# Session restore

Myoko saves its desktop and reopens it at the next login: the same windows,
on the same pages of the strip, with the same capacity per page. The code
runs inside Hyprland's own Lua runtime. `modules/session-restore.nix`
installs `session-restore.lua` and `session-plan.lua` next to
`hyprland.lua`, and `hyprland.lua` attaches the module when it finds it.
Hosts that do not import the module load no session code.

It restores windows, not their contents. Unsaved edits, terminal
scrollback, browser tabs and editor buffers belong to each application.

## Why it lives in the compositor

The first version patched a third-party Python script (hypr-session-restore)
and ran it as a user service. Four reboot trials on Myoko showed the limits
of that shape. Launch rules applied to the first window of a launch only, so
a single-instance application's second window landed wherever it opened.
Placement ran once after a fixed wait, so Zed, which waits for SSH before it
opens a window, arrived after placement ended. The strip renumbers pages, so
saved page numbers moved underneath the windows aimed at them. And the page
capacity lived only in `hyprland.lua`, where the service could not see it.

Hyprland 0.56's source (commit `efb50993`) and a live spike showed that its
Lua runtime can read and write files, that a named window rule applies to
every matching window until it is disabled, and that `window.open_early`
fires after rules choose a workspace and before the layout inserts the
window. Those three facts make the restore event-driven and let it share
state with the strip code.

## How it works

Saving. Every 10 seconds the module captures the desktop: each window's
class, title, page, floating geometry, pin and fullscreen state, the page
capacities, each multi-window page's split ratio and master side, and a
launch command read from `/proc/<pid>/cmdline`. Hyprland reports the ratio
on the master window (`layout.perc_master`), rounded to five places. It
does not report the side, so the module reads it off the master window's
position: with a window to its left, the master sits on the right. It writes
`$XDG_STATE_HOME/mountainous/session/snapshot.lua` only when two captures
in a row agree. At a reboot, logind sends SIGTERM to Hyprland and its
applications together. Windows close one by one, and that state never
holds still for 10 seconds, so a shutdown cannot overwrite the last good
snapshot. An empty desktop never replaces a saved one. Hyprland emits
`hyprland.shutdown` only for the exit dispatcher, not on SIGTERM
(`Compositor.cpp:92`), so the shutdown handler is a bonus for Super+Shift+E,
not the save path. A change made less than 10 to 20 seconds before a reboot
can be lost.

Launch commands. A Chromium `--app` window relaunches as `web-app <url>`
when its class matches the process's app URL. An installed PWA relaunches
through `chromium --profile-directory=<profile> --app-id=<id>`, using its
class, not its shared process's app identity. This supports `Default` and
the standard `Profile N` directories. It keeps other process flags, including
a custom user-data root, but replaces inherited app and profile switches.
A browser window relaunches
through the installed `chromium` wrapper; the unwrapped binary exits with
signal 4 on Myoko. Zed relaunches as `zeditor`, and Zed reopens its own
windows. Any other `/nix/store` path becomes its installed name when one
exists, so the snapshot survives garbage collection. One launch is saved per
process and class: a single-instance application opens its other windows
itself, and a Chromium app window can share a process with a browser window.

Restoring. Two seconds after `hyprland.start`, once Hyprland has published
its environment to systemd and D-Bus, the module reads the snapshot. A
desktop that already has a window is left alone. It restores each page's
capacity, holds the strip's compaction, and registers one disabled window
rule per saved window: the saved page, `silent`, and the saved floating
geometry. For each class only the next slot's rule is enabled. When a
window of that class opens, `window.open_early` claims the slot and enables
the next rule. So Zed's second window, which no launch carries, still opens
on its own page, and nothing flashes onto the current page first.

Five seconds after the last saved window opens, titles have settled. The
module pairs saved and restored windows of each class by exact title, then
by arrival order, and moves any window that landed on the wrong page. Then
it sets each page's split and side. Hyprland applies both to the focused
page only (`MasterAlgorithm.cpp:551`), so the module focuses one window on
each page that differs from the config's starting split and side, sends
`orientationright` and `mfact exact <ratio>`, and returns to the page you
were on. This happens inside one compositor callback, so the page change
may show as a brief flash. Only then does it swap windows within a page
into their saved order: which window is master decides where each window
sits, and the order is read from those positions. Then it disables the rules,
releases compaction, and resumes saving. If a window never opens, the
restore ends after 5 minutes, reports the missing classes in a notification,
and the strip closes the gap.

## Changes to the strip in `hyprland.lua`

These fix defects that restore exposed, and they apply to every host.

- Capacity follows a page when compaction renumbers it. Before, capacity
  stayed with the old id, so a two-window page could split after an earlier
  page closed.
- A config reload rebuilds capacity from the pages: a page holding N tiled
  windows keeps room for N. Before, a reload reset every page to one, and the
  next window to open split full pages.
- Compaction can be held. Only the session module holds it, while it places
  windows.
- Super+G reads the focused page's ratio and toggles that page between
  even and golden. It used to keep one flag file for the whole desktop, so
  after one page went golden the key did nothing visible on the next page.
  The logic is `hyprland/hypr-split.lua`, which the `hypr-split` command
  runs with `hyprctl eval` for the keybind and the omni bar.

## Limits

- Identity is a guess. Wayland gives a window no id that survives a
  restart. Two windows of one class with the same title can swap places.
- Chromium without its own session restore reopens one browser window per
  process, so a second browser window can stay missing. The notification
  reports it.
- Terminals reopen in their launch directory. Lua cannot read a process's
  working directory, and the overlay runs herdr, which keeps its own
  sessions.
- Only one master window per page is saved. Extra masters added with
  Super+A are restored as stack windows.
- Floating positions assume one monitor at 0,0.
- A config reload during a restore ends that restore. Saving stays paused
  until its deadline, recorded in `$XDG_RUNTIME_DIR`, so a half-restored
  desktop is not saved over the snapshot.
- Handlers run under Hyprland's 50 ms watchdog. An error shows as a
  notification; the module releases compaction on every error path.
- The module depends on Hyprland 0.56's Lua API, which is new and can
  change between releases.

## 2026-11-04 Chromium restore investigation

Read-only inspection on Myoko established the following. Times are MST.

| Evidence | Finding |
| --- | --- |
| Hyprland instance | The new instance started at 16:02:53. |
| User journal at 16:02:45 | The previous compositor dumped core during cleanup. The stack includes `hlGetWindows`, a Lua event callback and `CWindow` destruction. This is a separate shutdown defect; the browser's shutdown signal was not recorded. |
| Chromium's old `Session_13438306548314550` | Four normal windows remained saved before logout, including `amaze` and `amaze-next - Repos`. |
| Current `Session_13438306995759020` | Both windows existed in this session. `amaze` reached its login URL. Chromium then recorded window closures at 16:07:39.209625 and 16:07:40.237661, respectively. These times come from the command payloads, not file modification times. |
| Old/current `Apps_` files | Assistant and Teams were saved before logout. Only Teams exists in the new app session. |
| Live snapshot and `/proc` | Teams shares the normal browser PID. Its saved command was plain `chromium ... --kiosk`, with no `--app-id`. The installed session planner and restorer matched this branch byte-for-byte. |

The verified launcher defect is that installed PWAs inherited their shared
browser's command. Separate `spawn` flags did not help: both launches named
the browser rather than the saved app. The planner now reconstructs each
installed PWA's identity. This is the likely reason Assistant did not reopen,
but the overwritten pre-login snapshot prevents proof of its exact launch.
Chromium's app-session startup path only restores apps automatically after
a browser self-restart, not an ordinary Linux login. See Chromium
[153.0.8010.52 startup_browser_creator_impl.cc](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/ui/startup/startup_browser_creator_impl.cc)
(`ShouldRestoreApps`).

Simon then confirmed that he closed the normal windows himself after login.
Their absence is user action, not a restore bug. Neither the restorer nor
page overflow/compaction closes windows. The page-frame open handler only
changes fullscreen state. No normal-window restore change is needed.

A local experiment ran the same Chromium 153.0.8010.52 binary in a private
Xvfb with four windows and `--kiosk`, then sent SIGTERM. Chromium wrote
`SessionEnded`. Relaunch without restore flags opened one new tab;
`--restore-last-session` reopened all four. Adding
`--hide-crash-restore-bubble` also reopened all four. Thus kiosk plus SIGTERM
alone did not reproduce selective loss. This does not prove behavior after
a compositor crash or with Myoko's extensions. No browser policy, crash
bubble flag or CDP recovery mechanism was changed on this evidence.

After deployment, Simon must reopen the desired missing windows and wait
at least 20 seconds for a stable snapshot. Check that Assistant and Teams
have distinct `--app-id` commands. Then Simon must log out and log in and
check every window and page. The fix cannot recover entries already removed
from the snapshot. Custom-named Chromium profiles and arbitrary app URLs
that differ from the process's initial `--app` URL still need a separate
identity source, such as CDP; this change does not guess those URLs.

## Tests

`scripts/test-hyprland-session --plan-only` runs the pure planner cases,
including installed PWAs sharing a browser PID, app/profile switch replacement,
numbered profiles and preservation of a custom user-data root. The focused
flake check is `checks.x86_64-linux.hyprland-session-plan`, also a dependency
of the existing `checks.x86_64-linux.chromium-windows` check.

The full compositor model below currently needs updates: without the session
module its boot helper cannot load the now-required `duplicate-outputs`
module. The planner check does not claim to validate that integration.

`scripts/test-hyprland-session` runs the real `hyprland.lua` and both
modules against `scripts/lib/hypr-model.lua`, a model of the Lua API:
rules, workspaces, focus, timers and events. It covers launch commands,
capture, the two-capture rule, shutdown, a full restore with late and
reversed arrivals and a page destroyed mid-restore, one class across pages,
a missing window, a populated desktop, capacity after compaction and after
a reload, a mirrored golden page with its master restored, Super+G on two
pages, and a host without the module. Each of twelve deliberate breakages
of the code fails the suite. The model is not Hyprland; only a reboot proves
the real behavior.

The snapshot from the old service, `~/.local/state/hypr-session-restore/`,
is no longer read.

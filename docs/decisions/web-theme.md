# Web pages in the desktop theme

Status: built and verified in a nested session on 2026-10-23. Not deployed.

Chromium's pages take the active desktop theme's type, scroll bars and form controls. Page content colours stay the site's own. There is no injected window chrome and no DOM rewriting.

## Mechanism: CDP from Quickshell

`modules/quickshell/WebTheme.qml` opens its own browser-level CDP socket (separate from `CdpBrowser`'s). It sets `Target.setAutoAttach` with `waitForDebuggerOnStart` and `flatten`, filtered to pages; each page session auto-attaches its out-of-process iframes the same way. For every attached target it sends `Page.enable`, registers `web-theme-page.js` with `Page.addScriptToEvaluateOnNewDocument` (`runImmediately`), then `Runtime.runIfWaitingForDebugger`. A theme change re-registers the script; `runImmediately` restyles the open document in place.

The in-page script keeps one constructed `CSSStyleSheet` per section in `document.adoptedStyleSheets` and only calls `replaceSync`. It never creates a `<style>` element, so a strict `style-src` does not block it.

Spike evidence (nested Hyprland, Chromium 153, `/tmp/web-theme/logs/`):

| Test | CDP from Quickshell | Force-installed MV3 extension (spiked with `--load-extension`) |
|---|---|---|
| Styled before first paint, browser running | Yes: applied 34–142 ms, first paint 116–472 ms | Yes: content script 25–93 ms, first paint 88–284 ms |
| Cold browser start, first window | Yes, 5 of 5 (applied 67–89 ms, first paint 180–316 ms) | Yes |
| Strict CSP (fixture with `style-src 'self'`; github.com in the build) | Yes; an inline `<style>` on the same page was blocked | Yes |
| Window opened by a link (CdpBrowser relaunch) | Yes: applied 37 ms, first paint 76 ms | Yes |
| Cross-site iframe | Yes, only with `Page.enable` on each session | Yes (`all_frames`) |
| Cross-site navigation in the same window | Yes, only with `Page.enable` | Yes |
| Quickshell restarts | Open documents keep their styles. A document loaded while it is down is plain; it is restyled 0.74 s after Quickshell starts | Unaffected |
| Live theme switch | Native: 16–261 ms for 10 frames | Needs a second channel (native messaging host or CDP into the extension); not built |
| Install cost | QML and files that bars.nix already delivers | Packed CRX, signing key, update manifest, system-wide `/etc` policy for every Chromium profile; the policy cannot be tested here without root |

CDP won because it delivers the live switch with no new channel and no system policy, and it passed every first-paint test. Its costs:
- While Quickshell is down, new documents are plain until it reconnects.
- A stall in Quickshell's QML thread freezes windows that pages open. Closing the socket does not release them. A systemd watchdog bounds this; see "Stalls and the watchdog" below.
- Edits to `web-theme.js` need a Quickshell reload; edits to `web.css` apply live.

## Stalls and the watchdog

Measured on 2026-10-24 in a nested Hyprland (2880x1800 at 1.5, Chromium 153, Quickshell 0.3.1), with a local probe page that reports by beacon when its first script runs and whether the theme ran before it. Logs and scripts: `/tmp/ship-prep/session/` (`harness/`, `logs/beacons.jsonl`, `logs/trials-*.txt`).

Correction to the first version of this record: it said Chromium resumes a waiting target when the socket closes. That is wrong for windows that a page opens.

| Quickshell stalled (SIGSTOP), socket open | Result |
|---|---|
| New window from `web-app` (launcher, CdpBrowser relaunch) | Not held: loads in 150–250 ms, plain, restyled in place when Quickshell is back |
| Window a page opens (`window.open`, `target=_blank`) | Never loads. Its opener page freezes too (`Runtime.evaluate` times out), and Hyprland shows "Application Not Responding" |
| Same, after SIGKILL (socket closed) | Still frozen after 10 s, and after 96 s in another run. Released only when a client attaches and sends `Runtime.runIfWaitingForDebugger`; the next Quickshell's `attached()` does |
| Cross-site iframe in an already attached page | Held; released when the socket closes |
| Cross-site navigation in an attached window | Not held; styled (the registered script persists) |

An idle browser-level client that only sets `Target.setAutoAttach` (flatten, even with `waitForDebuggerOnStart: false`) and is then stopped freezes the opener the same way; one that only sets `Target.setDiscoverTargets` (as CdpBrowser does) does not. So dropping the pause does not remove the freeze.

Options, with "the theme ran before the page's own scripts" counted per window kind (windows / cross-site iframes / popups):

| Option | First-paint styling | Popup and opener after a stall |
|---|---|---|
| As built: pause pages and iframes | 30/30, 30/30, 30/30 | Frozen until Quickshell is restarted by hand |
| (b) No pause anywhere | 8/10, 1/10, 10/10 | Still frozen: the auto-attach alone holds them |
| Pause only iframes | 30/30, 30/30, 30/30 | Still frozen |
| **(a) As built plus a systemd watchdog (chosen)** | 30/30, 30/30, 30/30 | Released 4.3–4.4 s after the stall starts |

The watchdog: `WebTheme.qml` runs `systemd-notify WATCHDOG=1` every 0.5 s when systemd set `WATCHDOG_USEC`. The unit (`web-theme.nix`) has `WatchdogSec=20s` for start-up; the first ping sets `WATCHDOG_USEC=2000000`. `NotifyAccess=all`, because the sender is a child. `WatchdogSignal=SIGKILL`: with the default SIGABRT, Quickshell's crash handler restarted it in place in 2.1 s but put a "Quickshell has crashed" dialog on screen, and a stopped process never handles SIGABRT. The unit's existing `Restart=on-failure`, `RestartSec=2` brings it back, and the new instance resumes the waiting window.

Measured with Quickshell as a transient `systemd-run --user` unit with these settings:

| Stall | Killed | Restarted | Popup loaded (from its open) |
|---|---|---|---|
| Busy loop in QML, 12 s | +2.07 s | +4.32 s | 4.32 s, styled |
| SIGSTOP | +1.76 s | +4.01 s | 4.39 s, styled |
| Busy loop, `RestartSec=250ms` (not chosen) | +1.85 s | +2.35 s | 3.11 s, styled |

A window opened 2.3 s into the stall (Quickshell down) loaded plain in 139 ms and was restyled 2.3 s later, as before. No false restarts: three Platinum → Win98 → Platinum → alternate-fixture rounds, mode and Extra dark flips, three hot reloads of `shell.qml` and 30 s idle left `NRestarts=0`.

Costs: two `systemd-notify` processes a second. A real stall over 2 s restarts the whole bar. A popup opened during a stall waits up to about 4.4 s, of which 2 s is the unchanged `RestartSec`; lowering it to 250 ms gives about 3.1 s, but it changes crash-loop pacing against the default start limit (5 starts in 10 s), so it is left alone. A launcher window never waits.

## Files

| File | Role |
|---|---|
| `modules/quickshell/WebTheme.qml` | Socket, attach, register, push, watchdog pings; IPC `webTheme status` and `reapply` |
| `modules/quickshell/web-theme.js` | Pure policy: theme to stylesheet, sections, per-site opt-outs |
| `modules/quickshell/web-theme-page.js` | The in-page function |
| `modules/quickshell/themes/platinum/web.css` | Platinum tokens and the three levels |
| `modules/quickshell/web-theme.test.js` | Policy, in-page script in a fake window, lint of every theme's `web.css` |
| `modules/web-theme.nix` | `checks.web-theme`; Public Sans in `fonts.packages`; the Quickshell unit's watchdog |

## Theme contract (Win98 slot)

A theme opts in with one file, `modules/quickshell/themes/<id>/web.css`. Nothing else changes: no registry field, no QML.
- `/* @tokens all */`, then one `/* @tokens <mode> */` per appearance in `themes.json`. An optional `/* @tokens extra */` applies while Extra dark is on.
- `/* @level type */`, `/* @level scrollbars */`, `/* @level forms */`.
- Every selector starts with `:where(`, `:root` or a bare pseudo-element. No `url()`, `@import` or `@layer`. `web-theme.test.js` enforces these, the token names and the contrast floors for every theme it finds.
- A theme without `web.css` clears every page (verified: 108–256 ms with a fixture theme).

## Appearances

| Desktop | Pages |
|---|---|
| Light | Mac OS 8.1 Platinum controls |
| Dark grey | Dark Platinum, the same bevels on grey; wells get a #8c8c8c edge, as the desktop's black bar does, so they stay visible on dark pages |
| Extra dark | Same as dark grey. Extra dark only blackens the bar; page controls are not persistent chrome, and black controls would lose their bevels. Toggling it does not re-push pages (verified: 0 of 10 frames re-applied) |

## Type

ChicagoFLF (public domain, `modules/fonts.nix`) sets headings, buttons, pop-ups, labels, legends, table headers, tabs and nav links. Public Sans (SIL OFL 1.1, nixpkgs `public-sans`) sets body text through `html, body`. Measured roughly from the Geneva specimen image on Wikipedia, Geneva has an x-height near 0.72 of the cap height and a wide set ("Electrolytes" ≈ 10.3 x-heights wide). The candidates were measured from renders of the nixpkgs fonts. Public Sans measures 0.714 and 10.5; Inter 0.753 and 9.9; Atkinson Hyperlegible Next 0.743 and 10.1; Open Sans 0.752 and 9.7. Public Sans also shares Geneva's straight-tailed y, flat-cut terminals and spurless G. DejaVu Sans is close too but is not OFL.

## Per-site opt-outs

`sites` in `web-theme.js`: `off` drops levels, `skip` adds a selector list to every forms guard. Each entry records what broke.

## Limits

- Closed and open shadow roots are not styled (Reddit's faceplate controls, parts of YouTube Music).
- Canvas and WebGL content cannot be restyled.
- Chromium's own UI (permission bubbles, `<select>` popups, `alert()`) is not a page.
- Only native controls are styled. Buttons and fields that sites build from `div`s keep the site's look.

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
- `waitForDebuggerOnStart` makes a new page wait for Quickshell's QML thread. A long stall there delays new windows. Chromium resumes the target when the socket closes.
- Edits to `web-theme.js` need a Quickshell reload; edits to `web.css` apply live.

## Files

| File | Role |
|---|---|
| `modules/quickshell/WebTheme.qml` | Socket, attach, register, push; IPC `webTheme status` and `reapply` |
| `modules/quickshell/web-theme.js` | Pure policy: theme to stylesheet, sections, per-site opt-outs |
| `modules/quickshell/web-theme-page.js` | The in-page function |
| `modules/quickshell/themes/platinum/web.css` | Platinum tokens and the three levels |
| `modules/quickshell/web-theme.test.js` | Policy, in-page script in a fake window, lint of every theme's `web.css` |
| `modules/web-theme.nix` | `checks.web-theme`; Public Sans in `fonts.packages` |

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

# Scryer media view

An MCP App view (`ui://scryer/media.html`) for the `claw-scryer` endpoint. One
page draws two card shapes from the tools' `structuredContent`:

- **Search tiles** after `scryer_search`: each result with its kind (pixel art
  where a poster would be), year, the facts that tell same-named titles apart,
  library badges, and **Add** / **Monitor**. A series asks which episodes
  (all, future, missing and future, or chosen seasons) before anything changes.
- **Title card** after `scryer_title`: seasons as one mark per episode (on disk,
  wanted, upcoming, not monitored), the whole-show scope, and **Monitor** /
  **Unmonitor** per season and per episode. Episodes are in the full view.

Buttons call the app-only tools `scryer_add` and `scryer_monitor`. Each returns a
fresh read of the title; after a failure the view reads again (the title, or the
search for an add). The view draws only what Scryer reports. Deletes, restores
and other destructive actions are not in the view.

## Contract (structuredContent)

```
scryer_search  -> { view: "search", query, results: [{ key, name, kind: movie|series|anime, year, endYear?, ongoing,
                    network?, seasons?, runtimeMinutes?, overview?, poster?: https URL | null,
                    library?: { titleId, libraryName, monitored, monitorType?, hydration: ready|pending|failed, onDisk?: { have, total } } }] }
scryer_title, scryer_add, scryer_monitor
               -> { view: "title", title: { id, name, libraryName, kind, year, endYear?, ongoing, network?, overview?, poster?,
                    monitored, monitorType?, hydration }, seasons: [{ number, episodes: [{ id, number, name?,
                    airDate?: YYYY-MM-DD, monitored, onDisk, file?: { quality, sizeBytes } }] }],
                    movie?: { onDisk, file? }, done?: { action, libraryName? } }
scryer_add     <- { key, name, year?, library?: mine|family (default mine), monitorType: NONE|ALL_EPISODES|FUTURE_EPISODES|MISSING_AND_FUTURE_EPISODES }
scryer_monitor <- { titleId, monitorType }  |  { titleId, seasonNumber, monitored }  |  { titleId, episodeIds, monitored }
```

`monitorType` is null when Scryer has none recorded (common); the view then
words the scope from the monitored flags. Posters are absolute https URLs on
Scryer's own origin, which the resource declares in its CSP.

## Files

| Path | What it is |
|---|---|
| `src/app.js` | Host plumbing (ext-apps `App`), rendering, writes, model context |
| `src/plan.js` | Layout policy: a pure function of view, display mode and frame size |
| `src/model.js` | Pure data rules: contract parsing, episode marks, words |
| `src/pixel.js` | The kind in pixels, ported from the assistant's `pixel.tsx` |
| `src/media.css`, `src/media.html` | Styles and page template |
| `dist/media.html` | The built page. Committed; the Go endpoint embeds it |
| `harness/` | A static development host with a fake claw-scryer (`fake-scryer.mjs`) |

## Commands

Node 22 or later:

```sh
npm ci
node build.mjs           # after any change under src/, then commit dist/
node build.mjs --check   # the committed page equals a fresh build
npm test                 # plan, model and fake-endpoint tests
node harness/serve.mjs   # http://127.0.0.1:3177/?drawing=search-office
```

Harness parameters: `drawing` (a key of `harness/drawings.json`), `mode`
(`inline` or `fullscreen`), `theme`, `delay=<ms>` and `fail=<tool>` for the
view's own calls, `hydrate=stuck`, `blocked=1` (the host refuses the view's
calls, as OpenClaw's session policy did), `hold=1`, `error=1`, `press=<css>`
(click after load, `|` between several), `nofull=1`, `still=1`, and
`openclaw=1` (frame sizing as OpenClaw 2026.11.3 does it, including its
150 px full-screen fault).

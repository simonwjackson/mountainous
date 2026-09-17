# Browser Spine: CDP Control in QML

## Purpose
Chromium in `--app` mode has no address bar or tab strip. Navigation (`Ctrl+L`) and one-page-per-window enforcement are implemented over the Chrome DevTools Protocol (CDP) directly in Quickshell QML.

## Architecture
- **Pure QML Socket**: Quickshell imports `QtWebSockets 6.11.2` directly. No external daemon or helper binary is needed.
- **Port Discovery**: `CdpBrowser.qml` reads `<profile>/DevToolsActivePort` via `head -1` on a poller timer.
- **Active Window Targeting**: Hyprland's `activeToplevel` is resolved to a CDP page target by parsing the host in `app_id` (`chrome-<host>__-Default`) and tie-breaking by title.
- **Enforcement Loop**: When links are opened (`window.open` or `target="_blank"`), Chromium creates page targets with an `openerId`. The enforcement loop closes the stray target via `/json/close/<id>` and relaunches it as an independent `chromium --app=<url>` window.
- **Trade-off**: POST-generated popup pages cannot be reconstructed from a URL and are lost on close/reopen. This matches Kamoi's documented design limitation.

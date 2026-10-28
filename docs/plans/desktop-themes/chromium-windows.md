# Chromium windows: investigation and navigation subset (2026-10-28)

**Ctrl+L is implemented for normal Chromium and its popups under both themes.
The no-tab conversion is not enabled.** Chromium 153's extension popups hide
the origin; a native popup bridge cannot accept a live tab through `tabs.move`.
Ordinary Memory Saver also protects the only tab in each window.
Neither issue is a cosmetic detail. The supervisor asked that an origin-less
popup conversion stay disabled. No extension, PWA launcher rewrite or browser
engine change is installed by this branch.

Evidence: [/tandem/chromium-windows/](http://100.114.19.92:8765/tandem/chromium-windows/).
All browser work used private test profiles. No real profile, account, cookie,
PWA entry or running desktop was changed. The parent supplied a read-only
Myoko desktop-entry inventory; this worker did not SSH to Myoko.

## What ships

- Hyprland's conditional `CTRL + L` bind recognizes `chromium-browser`,
  `chromium` and `chrome-*`. `auto_consuming` consumes the original key only
  for Chromium. Other clients receive their original key, without a synthetic
  `pass` dispatcher. The bind does not depend on the desktop theme.
- Chromium's Nix wrapper adds `--remote-debugging-port=0`. This selects a
  random **loopback** port. It does not move or copy the profile.
- `CdpBrowser` discovers both the existing web-app root
  (`~/.local/share/mountainous/browser`) and normal Chromium's root
  (`$XDG_CONFIG_HOME/chromium`, normally `~/.config/chromium`). Each browser
  keeps its own process, cookies and endpoint. Pages carry their endpoint.
- Normal windows and native popups match a unique page title in the normal
  endpoint; the normal browser's ` - Chromium` suffix is removed. URL-named
  declared apps are restricted to the shared web-app endpoint, so a same-host
  normal-profile page cannot win their match. Installed
  PWA classes can use the same path in their original profile. Host-based
  declared web-app matching remains. Duplicate normal-window titles fail
  closed. They never select the first target in an array.
- A disconnected or ambiguous browser now says **“Cannot identify this browser
  window”** in the existing destination readout. Go/OK is disabled. It does
  not claim to open a replacement window. This is shared model behavior;
  neither theme gets new layout or styling.
- The legacy shared-root opener handler is **unchanged**, at the supervisor's
  request. It closes a stray target and relaunches its URL as `web-app` because
  some app-mode targets otherwise have no visible Wayland surface. It can lose
  form state and OAuth/window.opener relationships. This is an existing risk,
  not a safe promotion mechanism and not expanded to normal Chromium. Removing
  it now would introduce an unverified visible-link regression. A replacement
  remains part of the blocked no-tab work.

### Limits and security cost

Title matching is not a native window-to-target registry. Repeated page titles
are deliberately unavailable, and a stale/spoofed title is not authoritative
identity evidence. Custom user-data roots are not discovered. URL-named generic `--app` windows
manually launched in the normal root are not the declared shared-root contract. This is a bounded
improvement to the existing title/host matcher, not full browser-shell parity.
An already running browser needs a restart to acquire the wrapper's new flag.

CDP is a privileged, unauthenticated local control endpoint. Adding it to the
normal profile broadens the existing web-app endpoint's risk: local code that
can connect can control that browser and read its data. We do not set
`--remote-allow-origins=*` or bind a remote interface. A random port is not
authentication. Do not expose it through a proxy, firewall rule or port forward.

Chromium 153 permits debugging its default root; Google Chrome does not.
[`remote_debugging_server.cc`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/devtools/remote_debugging_server.cc)
limits the default-directory restriction to Google Chrome branding (except a
Chromium test hook). This is **Chromium**, not Google Chrome support.

### Rollback: one option

```nix
mountainous.browser.shellNavigation.enable = false;
```

Rebuild, close Chromium, and start a new desktop session. This removes the
normal-browser CDP flag and returns normal Chromium's Ctrl+L to Chromium. The
pre-existing declared-web-app Ctrl+L/CDP path remains. No profile migration or
cookie rollback is needed. The rejected extension/PWA conversion has nothing
to uninstall because it was never enabled.

## Exploration: tabs into popup windows

### (a) Our small extension

The private MV3 prototype uses `tabs.onCreated`, a startup query, and
`windows.create({type: "popup", tabId})`. Moving the tab keeps its WebContents;
it does not close a target and reopen its URL. The memory run converted 5, 15
and 30 pages into exactly 5, 15 and 30 windows. It retained one browser and one
GPU-process per profile. The separate prototype also tried a normal extension
bridge page which called `window.open` and attempted to move the original tab
into its child. That move was rejected.

**The direct extension popup hides the origin. The native bridge keeps its
location/security strip, but cannot accept the live tab.** Both are rejected,
not installed. These are two different failures, established from a fresh
profile and Chromium 153 source:

1. [`WindowsCreateFunction`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/extensions/api/tabs/tabs_api.cc)
   turns an extension's `type: popup` into **`TYPE_APP_POPUP`**, sets the app
   name from the extension ID and marks it untrusted. It does not create the
   plain `TYPE_POPUP` that the API's name might suggest.
2. [`WindowFeatureController`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/ui/window_feature_controller/window_feature_controller.cc)
   gives a plain untrusted popup a location bar. An app popup gets one only
   when it has an `AppBrowserController`. Our extension is not an installed
   web app and has no such controller. Thus there is **no location bar and no
   security chip**. Marking the source untrusted does not fix that branch.
3. [`BrowserNativeWidgetAuraLinux`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/ui/views/frame/browser_native_widget_aura_linux.cc)
   allows SSD for these non-web-app popups. That gives our caption, but a
   caption is not an origin display. A page controls its title.
4. A fresh extension bridge successfully creates a **plain native popup**
   through `window.open("about:blank", ..., "popup")`. It keeps Chromium's
   location/security strip and our SSD caption. But `TabsMoveFunction` calls
   `MoveTabToWindow(..., allow_other_window_types=false)`, which rejects a
   destination other than `TYPE_NORMAL`. The private test returns exactly
   **“Tabs can only be moved to and from normal windows.”** The bridge leaves the original page,
   its helper and an empty native popup; it cannot finish the promotion.
   `windows.create({tabId})` uses the permissive internal move path, but returns
   to the origin-less app-popup shape in point 1. No unsupported popup-policy
   change, debugger extension or Chromium binary patch was added.

The [windows API](https://developer.chrome.com/docs/extensions/reference/api/windows)
and [tabs API](https://developer.chrome.com/docs/extensions/reference/api/tabs)
document the move and event contracts. In particular, `tabs.move` documents
normal windows only. They do not promise that an extension-created popup has
the same security chrome as `window.open` from a web page.

An earlier bridge image was not valid proof: a missing startup sweep left a
normal browser untouched, and a reused profile could retain cached extension
code. The final bridge uses a startup sweep and a fresh profile. Do not use
those earlier images as evidence that the native popup lacks an origin bar.

#### Declarative loading at 153

`--load-extension=<Nix store directory>` works for an unpacked extension in
**unbranded Chromium 153**, verified with the private prototype. It must be on
the wrapper used for the **first** process in each user-data root. Subsequent
launches join that process; adding a flag to only a later launch is not enough.

[`ExtensionService::LoadExtensionsFromCommandLineFlag`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/extensions/extension_service.cc)
rejects this flag in Google Chrome branding, not our Chromium build. A future
safe extension can therefore be loaded reproducibly from a store directory in
the wrapper. Pin a stable public `manifest.key` so a changed store path does
not assign the unpacked extension a different ID on every update. Do not distribute a Google Chrome configuration using that path.

`ExtensionInstallForcelist` is for **packed** extensions. On Linux a self-hosted
extension needs a signed CRX and an update manifest served from an update URL;
see [Host on Linux](https://developer.chrome.com/docs/extensions/how-to/distribute/host-on-linux).
An unpacked directory is not a force-install policy value. A local `file://`
CRX/XML policy route was not tested and is not claimed to work. The private
prototype used the supported Chromium unpacked flag, not a new HTTP update
service, signing key or public publication.

#### Event coverage and remaining work

| Path | Finding / required handling before a daily-use trial |
|---|---|
| New tabs / initial URL list | Converted in the 5/15/30-page probe; existing tab identity is moved |
| Ctrl+T in a popup | Not a complete solution: a popup has no normal tab-strip command surface; needs a compositor command which creates a new page in the correct profile |
| Ctrl+N | A normal new window can be converted by `onCreated`; real shortcut/focus coverage remains incomplete |
| Middle click / `target=_blank` | Need both `onCreated` and `onAttached`, with background focus preserved; link sequence recorded in the rejected prototype |
| `window.open` / OAuth | Never close/relaunch the URL. Named windows, opener messaging, initial `about:blank`, transient activation and POST state need explicit tests |
| Session restore | Sweep existing normal windows on startup; preserve restored focus, geometry, discarded state and session identity; not validated as a daily-use path |
| Drag-out / attach | Use `onAttached`; Chromium rejects moves during a tab drag, so retry after the drag rather than dropping the event |
| Extensions' own popovers / DevTools | Do not convert devtools or extension UI; a browser action's popover is not an ordinary page tab |
| Worker restart / concurrency | Serialize moves, re-read current ownership, ignore already-owned single-page popups, retry bounded transient errors; no timer-only MV3 correctness claim |

The extension is a feasibility probe, not a finished event router. The unsafe
window shape is a stop condition before building daily-use machinery around it.

### (b) Every page as `--app=<url>`

This is the existing `web-app` path. It gets our SSD caption and no tab strip,
but also removes the normal origin/security display. It cannot move an existing
live tab by URL without losing its renderer state, history, POST data and
opener relationship. A launch wrapper also cannot intercept all browser-created
tabs. It does not solve a universal no-tab rule.

Installed PWA conversion can reuse the original profile and URL, but shares
the origin problem. The private PWA probe and supplied inventory are below.

### (c) Other paths

The estimates below are engineering opinion, not measured delivery times or
commitments. Each assumes an opt-in private-profile trial first.

| Route | Estimated prototype cost | What it does not solve / risk |
|---|---|---|
| Trusted shell security surface fed by CDP | 2–4 weeks, including a design engineer and exact window/target registry; 4–8 weeks for a daily-use trial | Own loading/disconnect/certificate/fullscreen states, permissions and accessibility. A title is not identity. Memory Saver's active-tab protection still needs a separate policy |
| `chrome.tabs.onCreated` → native host/shell launches `--app=url`, then closes the original | 2–5 days for a restricted Default-profile experiment; longer for multi-profile routing and restore | Loses live renderer state, POST data, history, opener/named-window relationships, transient activation and OAuth nonces. Must retain the exact original profile/cookies. Generic app windows still lack origin UI; **not enabled** |
| `--app` windows plus Hyprland groups | 3–7 days for a visible trial; 1–2 weeks for restore, popup, detach/regroup coverage | Group membership is not browser-tab state. Still needs state-preserving promotion and safe origin UI. Hiding individual windows in groups also conflicts with the dock-as-tab-container goal |
| Small Chromium patch to retain native popup location/security UI | 1–3 days for a patch/rebuild prototype, plus large builds and validation at every Chromium update | Could change the app-popup location-bar branch or allow moves into native popups. The fleet takes ownership of a Chromium patch/build; memory, restore, extensions and installed-PWA routing remain. No Chromium rebuild was attempted |
| One tab per **normal** window | 1–3 days for a restricted extension trial | Keeps native security UI but keeps the tab strip too. Every sole tab remains active/protected from ordinary Memory Saver. Not the requested appearance |
| Native `window.open` popup bridge | Tested here; no working promotion route | Creates the native security row, but `tabs.move` rejects its popup destination. Reopening a URL rather than moving the tab has the state-loss risks above |
| New WebKitGTK/Qt WebEngine shell | 6–12+ weeks for daily-use basics | Own security, permissions, downloads, sessions, accessibility, engine updates and site/media compatibility. Chromium profile/extension parity is not automatic |

This supersedes the old B/C recommendation to imitate tabs with Hyprland groups.
The requested unit is the window itself; compositor tab groups are not needed.
Phase A remains the safe default while these blockers are open.

## Memory: measured, not an estimate

Chromium **153.0.8010.52**, fresh private roots for each run, nested Hyprland
**0.56.2** under headless labwc. Output: 2880×1800, scale 1.5. Each run used
`--disable-gpu` with software GL; a GPU-process still exists. This is a Zao
software-rendered comparison under `/tmp/phase1/heavy.sh`, **not Myoko VRAM or
battery measurements**.

The same five public sites were repeated 1, 3 and 6 times with unique fragments:
`example.com`, `example.org`, `www.wikipedia.org`, `nixos.org`, and
`developer.chrome.com/docs/extensions/`. The saved targets confirm all five
sites loaded. Each run settled for 16 seconds after launch. There was no
login, private account or background application. Normal tabs and popup pages
use Chromium's real rendering/lifecycle choices; this is not an isolated
measurement of just the window object's allocation.

| Pages | Layout | Browser + children PSS MiB | Browser / GPU / renderer processes | Browser / GPU / renderer PSS MiB | Hyprland PSS MiB | live wl_shm buffers / MiB |
|---:|---|---:|---|---|---:|---:|
| 5 | tabs | 566.5 | 1 / 1 / 8 | 206.3 / 44.8 / 230.9 | 138.6 | 3 / 38.1 |
| 5 | popup windows | 1142.3 | 1 / 1 / 9 | 220.5 / 171.8 / 640.6 | 166.9 | 14 / 168.7 |
| 15 | tabs | 727.3 | 1 / 1 / 18 | 216.1 / 40.9 / 387.8 | 138.8 | 3 / 38.1 |
| 15 | popup windows | 2415.3 | 1 / 1 / 19 | 282.7 / 528.3 / 1486.1 | 251.1 | 43 / 524.8 |
| 30 | tabs | 974.1 | 1 / 1 / 33 | 234.3 / 45.3 / 610.6 | 138.8 | 3 / 38.1 |
| 30 | popup windows | 4073.3 | 1 / 1 / 34 | 381.4 / 854.2 / 2687.5 | 348.4 | 79 / 832.3 |

PSS comes from `/proc/<pid>/smaps_rollup`, summed over the browser's descendant
processes. It also includes 3 zygotes, a broker and 2–4 utility processes per
run; the renderer counts include the observer extension/spare/worker renderers,
not just pages. Detached crash-report helpers are not in that descendant sum.
The outer labwc stayed at about 64.4–64.9 MiB PSS. All reported swap PSS was 0.

`wl_shm_pool.create_buffer` and `wl_buffer.destroy` in the real Wayland client
log give the **live client buffer allocations retained for compositor use**,
including their actual stride × height. Those bytes overlap process PSS: do
not add that column to PSS again. The compositor's own output textures/driver
VRAM were not separately instrumented. Its actual PSS is reported instead of
inventing an exact GPU-buffer total.

At 30 pages the browser family used **4.18×** the PSS, about **3.03 GiB more**.
One full-size active page per window is not equivalent to 29 background tabs.
Surface buffers and the software GPU process grow substantially. Network
content, viewport size, retained surfaces and visible-page lifecycle all affect
the result. In the saved API data, initial background tab viewports are
945×1093, while popup viewports are 1896×1151; the active normal tab becomes
1896×1064. This includes real viewport/lifecycle differences, not merely the
cost of an equal-size window object. Repeat on Myoko before making a hardware
cost claim.

Artifacts: `memory.json`, `memory.md`, `logs/memory-{tabs,popup-windows}-{5,15,30}.json`,
`memory.mjs`, `measure.py`, and the corresponding Wayland logs under `session/logs/`.

### Memory Saver: automatic discard is not preserved

A separate private test successfully discarded a background normal tab and a
sole tab in an unfocused popup using **explicit** `chrome.tabs.discard(id)`.
Both returned `discarded: true` and `status: unloaded`. Chromium 153 gave the
replacement WebContents a **new tab ID**; reading the old ID caused the first
probe's misleading “No tab with id” error. `discard.json` and
`logs/discard-*-5.json` retain the corrected results. Any registry must follow
replacement identity, not keep the old tab ID forever.

That is **not** evidence that Memory Saver works normally. In 153,
[`DiscardEligibilityPolicy`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/performance_manager/policies/discard_eligibility_policy.cc)
returns early for an external discard. For proactive discards it protects a
visible page and `IsActiveTab()` **even when its window is not visible**. The
source comment explicitly says “Don't discard the active tab in any window”.
It also protects installed desktop PWA windows. Every one-tab window is an
active tab in its own window. `autoDiscardable: true` alone does not override
these protections. A replacement policy would need its own safe hidden-window,
audio/capture/form and reload-on-activation rules. That was not built.

## Toolbar and origin: what can be reused

Go to Address / Open remains the shared shell navigation path. Alt+Left,
Alt+Right, Ctrl+R and F5 are left to Chromium; no theme intercepts them. No
parallel history implementation or new theme-specific toolbar was added.
Normal browser windows retain Chromium's location/security UI and permission,
download and certificate-error surfaces. The origin-less app-popup prototype
must not be used as the daily browser.

If a future shell security surface is approved, the **data path**, not its UI,
should be:

1. Authenticate/select the correct local browser endpoint and keep an exact
   native-window ↔ browser-window ↔ target registry. Titles, favicons and
   origin strings from a renderer are not identity proofs.
2. Subscribe to browser `Target` changes and each selected target's CDP
   `Security` events. Track committed URL/origin, loading/unknown state and
   certificate/security errors. Modern CDP exposes
   `Security.visibleSecurityStateChanged`; do not assume the deprecated
   `Security.securityStateChanged` event is a complete contract at 153.
3. Publish one browser-owned state record to the shared shell owner. The
   caption/taskbar views may read it only after design and threat review.
   Certificate errors, disconnects, unsupported targets and redirects must
   fail to unknown/insecure, not retain an old secure indication.

A page can spoof its title, favicon and in-content browser-looking controls;
it can request fullscreen, open popups or attempt to align content with a
caption. Never use `document.title` or a DOM padlock as the trusted indicator.
Our surface must live outside the page's pixels/input region, and fullscreen
needs an explicit policy. This branch does not draw a replacement security UI.

## PWAs: inventory and scalable conversion boundary

The supplied Myoko inventory has three declared apps and eight installed PWAs:

| Entry | Launch / result |
|---|---|
| Forgerie | `web-app https://forgerie.hummingbird-lake.ts.net/` → `--app=` |
| Reddit | `web-app https://www.reddit.com` → `--app=` |
| YouTube Music | `web-app https://music.youtube.com` → `--app=` |
| Assistant | `--profile-directory=Default --app-id=ahmfndipfijlijminhiobipfjpafbndb` |
| Caliper | `--app-id=ephhkmeofmgblgjpkjnfjjlbojfjlcah` in Default |
| Household groceries | `--app-id=gehcogodmjijngibdplkjhkdjpkccahb` in Default |
| Pyxis | `--app-id=ghklfalheoohfhobcjmoijclhibhcehj` in Default |
| append | `--app-id=kgbpjefoeahnljaodhdhocnlefgggebf` in Default |
| Jellyfin | `--app-id=lneafpomhdmfgkblnkjeglpppndalpik` in Default |
| Microsoft Teams (PWA) | `--app-id=ompifgpmddkgmclendfeacglnodjjndh %U` in Default; `web+msteams` and `chromium` scheme handlers |
| Pace Goal Tracker | `--app-id=pbdginngdcogphkbiafcmdmgkbfpmoah` in Default |

Forgerie is not specially installed. The other eight desktop entries are under
`~/.local/share/applications`. Their start URLs are not in those desktop files.
No URLs were guessed from the app names. The inventory copies are under
`/tmp/tandem/pwa-inventory/`.

The scalable source is Chromium's **own** `chrome://web-app-internals` data,
not a guessed domain or a hand parser for its live LevelDB. At 153,
[`WebApp::AsDebugValue`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/web_applications/web_app.cc)
exports `!app_id` and `start_url`;
[`WebAppInternalsHandler`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/ui/webui/web_app_internals/web_app_internals_handler.cc)
gets installed apps from the registrar. An eventual launcher adapter could
resolve an ID through that page over the **same profile's** CDP endpoint,
cache only its launch metadata, and make reversible desktop-entry shadows.
The private fixture successfully exports that registrar JSON through CDP from
`web-app-internals-app.rawDebugData_`, including the real installed fixture's
`!app_id` and `start_url`. This is a pinned internal WebUI contract, not a
stable external API. The first installation attempt over TCP correctly lacked
the unsafe PWA handler; fixture installation uses a private debugging **pipe**,
inside the same render-only device namespace. No unsafe-operation flag or pipe
is added to the production wrapper.
It must preserve each entry's executable/profile flags and Icon, not route a
Default-profile PWA through today's `web-app` command into a different root.

The private normal page, installed fixture and generic `--app` launch all see
the same test cookie, `session=private-login`. The generic app's observed class
is `chrome-127.0.0.1__fixture-Default`, which also demonstrates that URL paths,
not only hosts, participate in that class. The standalone installed fixture
has class `chrome-<app-id>-Default` and Chromium's own caption; the generic app
has our SSD caption but no origin strip. Both launch shapes were captured
under Platinum and Win98. This confirms cookie retention, not protocol-handler
or installed-app parity.

| Property | `--app-id` → same-profile `--app=start_url` |
|---|---|
| Cookies / logins / site storage | Stay in the same root and profile; do not copy or merge profiles |
| Desktop name and icon | Can remain on the shadow entry |
| Native window class | Changes to Chromium's URL-derived class; Wayland ignores `--class`; StartupWMClass/icon mapping needs updating |
| Badging / installed-app identity | Not equivalent; app-controller/OS integration is lost |
| Protocol/file handling / launch queue | Not equivalent. Keeping `%U` text is not enough; Teams custom-scheme delivery must not be silently broken |
| Manifest scope / app routing | Installed-app routing is not the generic `--app` contract |
| Origin/security title bar | Lost; this blocks enabling the rewrite without a safe replacement |

**The automatic PWA-to-`--app` conversion is not implemented or shipped.**
The private launch/cookie/registrar prototype is tested; a reversible launcher
adapter and protocol semantics are not. The eight installed apps' real start
URLs remain unknown, not guessed. There is no speculative URL list to approve.
No installed PWA was uninstalled, no launcher was overwritten, and Simon keeps
his existing logins. Open item 7 remains blocked, rather than calling unsafe
origin removal a scalable fix. The shell can now navigate an identifiable
installed PWA in its original profile without converting its window.

## Taskbar and Control Strip

The taskbar and strip already enumerate **windows**, not an app count.
`lanes.js` keeps every toplevel in its screen/page lane. Win98's task model also
keeps minimized windows. `app-model.js` groups the same Wayland class into one
Application-menu app **with all its windows**; that is not the tile/button
model. The new 30-window test confirms one Chromium app group contains 30
unique windows and Win98's window cycle contains all 30.

Titles are already per window. Favicons are **not** complete: both themes
normally resolve a desktop-entry/app-class icon. The extension's shared class
would give repeated generic browser icons, not page favicons. `CdpBrowser` now
retains `/json/list` favicon metadata, but no unreviewed icon/UI path was added.
A future exact target registry can supply it through the existing icon slots.

Opinion: keep individual windows reachable and make **optional origin/site
groups** only in overflow/app menus if a trial proves crowded. Use the browser's
committed origin, not title parsing. Grouping reduces scan cost but adds a tap
and must not hide same-site windows. The existing scroll/overflow paths remain
the fallback. This needs design review, not a second application-group model.

## Checks and evidence

`checks.chromium-windows` runs the real Lua binding test, CDP matcher tests,
Find model tests, 30-window app-model coverage, the packaged Chromium wrapper
flag assertion and focused QML type/lint checks. The lint helper accepts a
pinned toolchain from a Nix check so it does not invoke nested Nix builds.
Its complete singleton index is test-only; no qmldir is delivered to Quickshell.
`checks.titlebars` and the 22 lane checks also passed during development.
No aggregate check or full suite was run.

The real Quickshell, both themes, Chromium and virtual keyboard ran in the
private nested session. A separate native-popup test opened the real shell
under both themes and navigated that popup without changing its target ID.
The Chromium-native location/security row remained visible. Ctrl+L opened Go to Address / Open and navigated the
existing page under Platinum light/dark and Win98 light/dark. Four snapshots
of `/json/list` verify the resulting URL/title. A second real-key run with two
identical page titles verifies Go/Enter changes neither target under all four
light/dark theme combinations; the disabled buttons and explanation are
captured. Socket-closure recovery and fixture-page preservation are also
covered by the focused CDP tests. The harness waits for keyboard
acknowledgement; its first input test checked too early while text was still
being typed and is not used as passing evidence.

Screenshots, rejected-prototype filmstrip, memory tables, source excerpts,
commands, logs and cleanup scans live in the evidence directory. Nested
compositors/clients used a private `/dev` with only `renderD128`, nonexistent
`AQ_DRM_DEVICES`/`SEATD_SOCK`, a private runtime and private D-Bus. No real seat
or card node was used. Real Myoko input, its GPU/VRAM, long-term restore,
automatic discard, PWA protocol delivery and page favicon rendering remain
unverified or explicitly blocked. The parent lands and deploys.

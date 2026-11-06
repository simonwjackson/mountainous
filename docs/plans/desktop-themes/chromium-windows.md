# Chromium windows: page-only frame and navigation

## Current config (2026-11-04)

Normal Chromium, `--app` windows and installed PWAs now use client-only
fullscreen. `hyprland.lua` matches `^(chromium-browser|chromium|chrome-.*)$`
with `fullscreen_state = "0 2"` and `suppress_event = "fullscreen"`. Chromium
hides its tab strip, toolbar and PWA title bar while Hyprland keeps it tiled.
The hyprbars patch draws our Platinum or Memphis caption when the client
is fullscreen but the compositor is not, even for client-decorated windows.
This replaces the old assumption below that installed PWAs must keep their
Chromium frame. It does not ship the rejected extension popup conversion.

Installed PWAs stay installed and keep their original `--app-id` launchers,
profiles and logins. They retain periodic background sync, persistent storage
grants, remembered File System Access, protocol/file handlers, badging and
manifest scope. There is no PWA-to-`--app` launcher rewrite.

**Super+U** toggles the active Chromium window's client state between 0 and 2,
always with internal state 0. Use it to show the address bar and menu when
installing a PWA, then return to page-only mode. Other clients do not change.
`mountainous.browser.kiosk.enable` adds `--kiosk` to suppress the fullscreen
Esc bubble. It is off by default, because `--kiosk` also blocks DevTools and
the page right-click menu. **Cost when on: F11, DevTools and the right-click
menu do nothing.** Restart Chromium to
pick up wrapper changes. The named local `CHROMIUM_FAKE_FULLSCREEN` flag
can disable both the fullscreen rule and Super+U.

Security cost: the native origin/security display is hidden too. Our caption
and a page title do not prove origin. Super+U recovers Chromium's UI; no
replacement security display ships. CDP's existing local-control risk remains.
The earlier investigation below documents why a popup conversion was rejected;
it is historical evidence, not a claim that native origin UI stays visible
with the new fullscreen rule. Daily-profile kiosk behavior, permission prompts,
downloads, printing, extension popups and a real installed PWA with the patched
plugin need post-deployment checks on Myoko. Local headless checks do not
replace those checks.

## Earlier investigation and navigation subset (2026-10-28)

At this stage Ctrl+L shipped for normal Chromium and popups under both themes.
The origin-less popup conversion stayed disabled. The observations below
predate the client-only fullscreen rule; normal windows then kept browser UI,
and installed PWAs kept Chromium's frame.

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

### Navigation rollback

```nix
mountainous.browser.shellNavigation.enable = false;
```

Rebuild, close Chromium, and start a new desktop session. This removes the
normal-browser CDP flag and returns normal Chromium's Ctrl+L to Chromium.
To restore the ordinary frame too, disable `CHROMIUM_FAKE_FULLSCREEN` as above. The
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
Before the client-only fullscreen change, normal browser windows retained
Chromium's location/security UI and permission, download and certificate-error
surfaces. The current rule hides the browser UI until Super+U restores it. The origin-less app-popup prototype
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
has class `chrome-<app-id>-Default` and, without fake fullscreen, Chromium's
own caption; the generic app
has our SSD caption but no origin strip. Both launch shapes were captured
under Platinum and Memphis. This confirms cookie retention, not protocol-handler
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
his existing logins. The launcher rewrite remains unnecessary: current config keeps installed apps
and replaces only their visible frame through client-only fullscreen. The
shell can navigate an identifiable installed PWA in its original profile
without converting its window.

## Taskbar and Control Strip

The taskbar and strip already enumerate **windows**, not an app count.
`lanes.js` keeps every toplevel in its screen/page lane. Memphis's task model also
keeps minimized windows. `app-model.js` groups the same Wayland class into one
Application-menu app **with all its windows**; that is not the tile/button
model. The new 30-window test confirms one Chromium app group contains 30
unique windows and Memphis's window cycle contains all 30.

### Per-window favicons

Both themes keep their existing per-window icon slots. Installed Default-profile
PWAs prefer their desktop entry's absolute `Icon=` PNG, even when the PWA's
prefixed title cannot match CDP. Other pages use declared `rel=icon`,
`apple-touch-icon` and manifest icons read through a bounded, read-only CDP
`Runtime.evaluate`. Choose the smallest declared size at least as large as the
physical slot; otherwise try an unknown-size source (which can be a multi-size
ICO), then the largest undersized source. CDP's `/json/list` `faviconUrl` remains
an unknown-size candidate. Only HTTP(S) page icon URLs are accepted.

Discovery is cached by target websocket, page URL and CDP favicon URL. It runs
once per observed navigation/icon change, not on every target-list poll.
Manifest fetches stop after 1.5 seconds; evaluation sockets stop after 2.5 seconds.
Closed targets lose their metadata, and late replies cannot update a different
navigation. A same-URL SPA change which changes only link/manifest declarations
is not rediscovered until the CDP favicon URL changes or the shell restarts.

Decode raster icons at native size. Inspect up to 64 ICO frames and choose the
smallest frame covering the slot, or the largest frame if none covers it.
Directory order is not size order. Use the containing window's device pixel
ratio: Wayland's `QScreen` can report 2 while the actual window uses 1.5.
Smooth downscales, with mipmaps on GPU; use nearest-neighbour for exact-size and
undersized sources. A 16px-only source in a 24px slot keeps its size and has
uneven pixel widths rather than interpolated blur. We do not shrink the icon
inside the slot to obtain an integer scale. SVG URLs rasterize at the requested
size. Reset `sourceSize` as one QSize, not separate width/height assignments:
the latter can retain the previous image's resolved decode size.

Missing, ambiguous or failed page images still fall back to the existing themed
app icon. A missing installed PWA PNG first falls back to page discovery. The
Memphis taskbar keeps 16 units (32 physical pixels; 21 1/3 logical pixels at 1.5x).
A 16-logical-pixel Platinum row needs 24 physical pixels. Grouped Application-menu
entries keep their app-level icon. Window submenu rows, Find results and
individual Control Strip tiles use per-window icons.

`checks.app-icons` checks this contract in the real taskbar and Control Strip
at scale 1.5. Its former ban on installed-PWA colours and unconditional Jellyfin
and Teams lettermark expectations were obsolete after per-window icons, not
production regressions. Lettermarks remain required when no site or installed
icon exists. The check now gives each window a different original synthetic
icon through private HTTP target lists and desktop entries. It compares each
window separately with its own PNG (Memphis) or the packaged renderer's 36 px
token in the 32 px strip box (Platinum). Jellyfin has no matching CDP title;
Teams has a conflicting page icon. Both must prefer their installed icon.
A second session has neither site nor installed icons and must draw theme art,
including Reddit, Jellyfin and Teams lettermarks and the themed browser for an
unknown site. Upstream Chromium-logo colours remain forbidden in both sessions.
The check supplies the same pinned Platinum helper as the desktop service;
without it, a raw favicon must fail the token comparison.

Cost: native decoding and frame inspection use more memory than a pre-sized
image. Frames are capped at 64. Discovery can fetch a site's manifest in Chromium,
and Qt makes its own icon requests without Chromium's profile/cookies. The site
can observe these requests. Protected icons can still fail. Favicons remain
page-controlled decoration, not identity/security indicators.

#### Source and renderer evidence (Zao, Myoko queried read-only)

| Real source | Native frames in directory order | Previous Qt default |
| --- | --- | --- |
| Teams favicon ICO | 256, 64, 48, 40, 32, 24, 20, 16 | frame 0: 256 |
| Amaze UAT and local Amaze ICO | 48 | frame 0: 48 |
| Forgerie ICO | 16, 32, 48 | frame 0: 16 |
| Installed Teams PWA | hicolor PNGs: 32, 48, 128, 256, 512; `Icon=` points to 512 | themed app fallback because the prefixed title did not match |

Teams also declares manifest PNGs including 32px; ordinary Teams pages can use
that source. At a 24px slot, Forgerie now selects its 32px frame; at 32px it uses
that frame without resampling. The review page declared no icon and keeps its
fallback.

`/tmp/favicon-sharp-evidence/` holds downloaded real files, read-only CDP icon
metadata, Qt frame logs, and before/after PNGs. `before-wayland-1.5x.png` and
`after-wayland-1.5x.png` use Myoko's exact Hyprland build inside private headless
labwc on Zao. The headless output runs at 1.5x; the GPU Qt renderer uses native
24/30/32/48px slots. `before-1.5x.png` and `after-1.5x.png` repeat the comparison
with Qt's offscreen software renderer. The 16px-only case extracts the real
Teams ICO's 16px frame. No screenshots or window actions ran on Myoko, and no
code was deployed. Live Myoko GPU rendering, theme effects and preference for
the new sampling rule still need on-device verification after an approved deploy.

A unique host/title match wins first, within the correct CDP endpoint. On a
focus change with tied matches, `CdpBrowser` evaluates `document.hasFocus()`
only on those candidate pages. All replies must complete within one second,
with exactly one true result and the same window still active. The shell then
records window address → page id. Zero, multiple, failed, timed-out or stale
reports do not establish a mapping. Closing a window or losing a page removes
its record. Navigation keeps the page id, so the icon follows the new URL.
The volatile map is not a second browser history and does not change the
navigation/security matcher.

**Known gap:** two same-title windows that have not been focused since the
shell started show the Chromium icon until each is focused once. Custom
user-data roots remain unsupported. A shell restart clears focus evidence.

Opinion: keep individual windows reachable and make **optional origin/site
groups** only in overflow/app menus if a trial proves crowded. Use the browser's
committed origin, not title parsing. Grouping reduces scan cost but adds a tap
and must not hide same-site windows. The existing scroll/overflow paths remain
the fallback. This needs design review, not a second application-group model.

## Checks and evidence

`checks.chromium-windows` runs the real Lua binding test, CDP matcher tests,
Find model tests, 30-window app-model coverage, the packaged Chromium wrapper
flag assertions (CDP and kiosk), focused QML type/lint checks, pure source/frame
choice tests, and an isolated Chromium + Qt runtime test at 1.5x. The runtime
test proves apple-touch/manifest discovery, manifest-relative URLs, installed
PWA lookup, native ICO frame choice, sampling, and HTTP/no-icon fallbacks. The Lua
binding test also covers the fullscreen rule, Super+U and the local disable flag. The lint helper accepts a
pinned toolchain from a Nix check so it does not invoke nested Nix builds.
Its complete singleton index is test-only; no qmldir is delivered to Quickshell.
`checks.titlebars` and the 22 lane checks also passed during development.
No aggregate check or full suite was run.

The real Quickshell, both themes, Chromium and virtual keyboard ran in the
private nested session. A separate native-popup test opened the real shell
under both themes and navigated that popup without changing its target ID.
The Chromium-native location/security row remained visible. Ctrl+L opened Go to Address / Open and navigated the
existing page under Platinum light/dark and Memphis light/dark. Four snapshots
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
automatic discard, PWA protocol delivery and on-device page favicon rendering remain
unverified or explicitly blocked. The parent lands and deploys.

### Platinum favicon tokens (direction A)

`scripts/platinum_icons.py` exposes the pure `render(frames, size, theme)`
function. It returns RGBA or `None` for empty art. It does not use AI, randomness,
fonts, network access or browser state. Nix pins Pillow, numpy and librsvg.

- The favicon stays flat and front-on. Compact solid silhouettes extrude their
  own outline. Rings, clusters, thin and wide marks use a small Platinum plate.
- Colours use the Mac OS 8 system palette. Alpha edges are 1-bit. The outer black
  outline is one device pixel. Light comes from the top left. The hard shadow
  falls down-right. The light plate remains light in both modes for dark glyphs.
- Reserve **`M(S) = max(2, floor(S/16))`** on all four sides: 24, 30 and 36→2,
  48→3 device pixels. (Simon asked for bigger tokens on 2026-11-04: the margin
  went from S/12 to S/16, the body depth from up to 6 px to `max(2, S/12)`,
  the shadow to 1 px and the plate border to 1 px. Since 2026-11-05 the
  Control Strip draws every icon at one optical size; see "Strip optical size".)
  `RENDER_VERSION` is part of each cache key; bump it with any drawing change. The band must contain no non-transparent pixel,
  including outline, extrusion and shadow. Transparent source padding is trimmed.
  The entire composite fits the inner `S−2M` box, using its full longest axis.
  Centre its bounds with floor division; an odd spare pixel goes right/bottom.
  No source-specific offsets or resampling of the finished art are allowed.
- ICO selection uses the smallest frame covering the requested device slot,
  otherwise the largest. PNG and first-frame GIF/WebP/APNG work. SVG is rasterised
  through `rsvg-convert` on stdin, without a local resource base URL.

`mountainous-platinum-icon SOURCE SIZE platinum-light|platinum-dark` prints a PNG
path, or nothing on failure. `SOURCE` is an HTTP(S) URL or an absolute local file
(including a PWA's `Icon=` file). Fetches use no Chromium cookies, authentication,
Referer or proxy credentials. Sources are limited to 2 MiB and 4 megapixels.
The CLI has a 12-second deadline; the QML process has a 15-second backstop.

The content cache is
`$XDG_CACHE_HOME/mountainous/icons/<sha256(source bytes)>-<S>-<theme>.png`,
defaulting to `~/.cache/mountainous/icons/`. Writes use a temporary file plus atomic
rename under a lock. The cache keeps at most **512 PNGs / 32 MiB**, pruning least
recently used files by mtime. It also removes abandoned temporary PNGs. Changing
source bytes at the same URL produces a new key. A mounted icon is requested again
when its URL, size or mode changes; there is no additional periodic URL polling.
After a future renderer change, clear this disposable cache or add versioned
invalidation before release.

The desktop module installs the helper and pins its path in the Quickshell user
service. `PlatinumToken.qml` runs it asynchronously. `WindowIcon.qml` keeps today's
icon until the cached PNG decodes. Late replies cannot replace a newer request.
`PlatinumAppIcon`, Find and Go to Address opt in; the strip and window menu share
that path. The PNG child draws at `S / devicePixelRatio` logical pixels with
filtering off. Memphis does not opt in. No installed-app theme icons change here.

For installed apps, the same pure renderer runs at build time
(`scripts/platinum-app-tokens.py`, `mountainous-platinum-app-tokens`). The
desktop module's `environment.extraSetup` reads the finished system path and
writes `share/icons/Mountainous-platinum-apps`, which Mountainous-platinum
inherits first:

- `32x32/apps/<name>.png`: for each desktop entry whose `Icon=` theme name has
  no 32 px art in Mountainous-platinum, the app's own hicolor or pixmaps icon
  as `boxed(frames, 32)`. On Myoko (2026-11-05 build): Sunshine, Kvantum,
  nix-snowflake, Quickshell and Syncthing.
- `<C>x<C>/apps/mountainous.strip.<name>.png`: the Control Strip's tokens (see
  "Strip optical size"), for every desktop entry's icon, every app name
  Mountainous-platinum draws, and the strip's fallbacks `chromium` and
  `application-x-executable`. The source is the theme's own art at its
  largest size, else the app's own hicolor or pixmaps icon. Browser and
  web-app fallbacks keep the theme's cube/lettermarks, not Chromium's logo.
  Made for scales 1 (22 px) and 1.5 (30 px) only: Qt looks an icon up at the
  scale rounded up (20 logical px at
  1.5 as 40) and takes the nearest directory, so a 40 px directory for scale 2
  won 1.5's lookup and was scaled to 30 (seen in `checks.platinum-strip`).

It does not call the URL/cache CLI and does not fork the geometry. Not
covered: a path `Icon=`, `-symbolic` names, apps from a user profile.

### Strip optical size (2026-11-05)

`strip-plan.js tileGeometry(dpr)` is the one source; `PlatinumStripTile`
draws it and `strip-plan.test.js` and `theme-dev/platinum-strip.sh` check
it. Simon's feedback on the 32 px box: a token's opaque art filled ~30 of
32 px, 7 px from the bevel, and read as cramped; a Chromium window with no
page icon showed the theme's 32 px cube, whose opaque body is ~22 px, so it
read as tiny. Theme art's opaque extents range from 18 to 32 px over the 84
32 px app icons, so 1:1 art cannot have one size.

The rule: every strip icon is a Platinum token whose **opaque bounds**
(outline, depth and shadow included) are one extent on their longest side,
centred by those bounds in the box. `platinum_icons.render_extent(frames,
extent, canvas)` renders at the token sizes around `canvas_for(extent)` and
keeps the one whose opaque bounds hit the extent (render() is deterministic;
the finished pixels are never resized). Sources:

| Tile | Token |
| --- | --- |
| Chromium window or PWA with a site icon | run-time, `mountainous-platinum-icon SOURCE 30 THEME --extent 26` (cache name `<digest>-30e26-<theme>.png`, `RENDER_VERSION` 3) |
| Same, before its token arrives or if the helper fails | the build-time token for its name (a web app's fallback: `chromium`) |
| Chromium window with no page icon | build-time `mountainous.strip.chromium`, from Mountainous-platinum's cube art |
| Any app | build-time `mountainous.strip.<name>` from theme art when available, else the app's own icon; missing token: `mountainous.strip.application-x-executable` |
| No app id yet | the title's letter (text, unchanged) |

At scale 1.5, in device px (measured in `checks.platinum-strip`, light, dark
and black, 27 tiles with icons):

| Part | Before (bddea926) | Now |
| --- | --- | --- |
| Tile | 60 × 48 | 60 × 48 |
| Icon box | 32 × 32 at (8, 8) | 26 × 26 at (11, 11): the optical size |
| Opaque size | token 32, theme cube 28 × 26 | 26 × 26 for every tile |
| Padding, inside of the bevel to the opaque bounds | token 6, cube 6–9 | 9 left, top and bottom for every tile (`ICON_PAD` 6 logical) |
| Token canvas | 36 at (6, 6) | 30 at (9, 9): the box and a 2 px margin |
| ▴ | 11 × 8 at (45, 36) | unchanged |
| Box to ▴ | 5 at rest, 4 pressed in | 8 at rest, 7 pressed in; nearest icon px to the ▴ 8–13 |

Why 26: in a side-by-side of 24, 26 and 28 (Chromium, a theme-art app, Teams
and Assistant), 28 leaves 8 px to the bevel, near the 7 px Simon called
cramped; 24 leaves 10 px and the ▴ starts to compete with the icon; 26 is
the largest size that keeps 9 px. In the black scheme a raised tile's face is
black, so a token's black outline and shadow do not show: the visible size is
23 px, the same for every token.

Pressed in, the icon moves 1 px down and right. Every token draws through
`WindowIcon.artPixels` (the build-time token, 30 px, which Qt returns
unscaled) or as the run-time token's PNG, both at 30 px with filtering off.
Inactive tiles keep the one-device-pixel checker. At scale 1 the box is 18 px
(22 px canvas). At other scales the geometry holds but the build-time tokens
are the nearest made size, scaled by Qt.

**Verified:** `checks.platinum-icons` runs nine tests, including 54 synthetic
shape/size/mode combinations, byte determinism, margins, palette membership,
transparent padding, frame choice, real HTTP, SVG/animation, atomic concurrent
writes, content keys, failure fallback and both cache limits. Synthetic fixtures
avoid redistributing favicons without established licences.
`checks.chromium-windows` exercises the packaged helper through real Chromium and
Qt at 1.5x (24/30/48 px, light/dark and installed PWA), and runs QML lint.
`platinum-desktop`, `find-menu` and `bar-delivery` assert callers and delivery.

**Visual evidence:** `/tmp/platinum-token-evidence/platinum-{light,dark}-pil.png`
contains 1:1 strip/window-menu **PIL mocks**, using the exploration's real favicons
and the production renderer. `*-pil-3x.png` is a nearest-neighbour inspection copy.
`real-corpus-results.json` records 78 successful real-source size/mode cases and
one empty-source fallback. The nested Hyprland loaded the production components
and token PNGs, but its evidence assertion counted hidden empty icon slots and
failed before capture. **In-shell visual rendering remains unverified.** The
operator requested the PIL fallback after that attempt. No deployment or Myoko
window action/screenshot ran. Small-icon legibility on Myoko's panel remains an
on-device follow-up; the required margins reduce the favicon's front-face area.

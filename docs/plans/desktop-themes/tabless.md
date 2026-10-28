# Tab-less: normal page windows (2026-10-28)

**Keep this as an opt-in trial, not the desktop default.** Normal windows fix
our earlier origin/security blocker. Collapsed vertical tabs remove the
horizontal strip, but still cost 55 logical px at the left. Session restore
can expand them again. At 30 pages the browser family used 3719 MiB PSS,
versus 974 MiB with tabs. Ordinary Memory Saver does not solve that cost.
Forty generic Chromium icons also make window selection difficult.

Evidence: [tabless/](http://100.114.19.92:8765/tandem/tabless/).
No real profile, account or desktop was changed. The parent lands and deploys.

## What was tested, and what ships

| Boundary | Result |
|---|---|
| Detach behaviour | Private **plain-JS behavioural copy**, not the Store build, of `utils/detach-new-tabs.ts` at v0.7.0, commit `e346330a9c282287b4740049ee7c06616d3b506b`. Same index-0/pinned exceptions, startup/install sweep, `windows.create({tabId, incognito, state})`, concurrency and lack of `onAttached` handling. Observer is a separate test extension. |
| Upstream licence | The tag's `LICENSE.txt` and `package.json` say **LGPL-3.0**, not MIT. Copies are in `sources/` and `detach-copy/`. |
| Source build | WXT/Nix attempts were stopped or failed. Per the revised brief, no source build, source input or npm dependencies ship. These attempts are not passing evidence. |
| Declarative install | `mountainous.browser.tabless.enable`, **default false**, adds the Web Store ID/update URL through NixOS's `programs.chromium.extensions`, which emits `ExtensionInstallForcelist`. No unpacked production extension or second ID. |
| Preferences | When enabled, first-run `initial_preferences` seeds `vertical_tabs.enabled = true`, `collapsed_state = true`, `expand_on_hover = false`. It retains the existing system-frame/GTK seeds. No flag or live-profile preference rewrite. |
| Real policy | The enabled Myoko evaluation emits `/etc/chromium/policies/managed/default.json`. That exact file loaded in the private browser: `ExtensionInstallForcelist`, Platform / Machine / Mandatory, **OK**. `policy-loaded.png`, `logs/policy-loaded.txt`, `logs/myoko-tabless-enabled.json`. |
| Installation itself | **Not verified.** The Store-install probe failed with a missing target. It does not establish the cause, successful installation, duplicate avoidance or removal behaviour. Further download attempts were stopped as requested. Confirm these on Myoko after deployment. |

The install is declarative in **ID and update source**, not pinned bytes. Store
updates can change behaviour after a Nix rebuild. This is the Store copy Simon
already trusts, not a claim that Nix reproduces its package.

Enable a trial with:

```nix
mountainous.browser.tabless.enable = true;
```

Existing profiles need Settings ▸ Appearance ▸ Tab position ▸ Vertical, then
the strip's collapse control. The first-run seed does not migrate Simon's
existing profile. Turn the option off to remove our policy and first-run seed;
it does not regroup open windows or revert an existing vertical-tabs choice.

**Removal is not a return to manual management.** Chromium's
[policy definition](https://github.com/chromium/chromium/blob/153.0.8010.52/components/policy/resources/templates/policy_definitions/Extensions/ExtensionInstallForcelist.yaml)
says that removing a force-installed ID automatically uninstalls it.
[`ExternalProviderManager`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/extensions/external_provider_manager.cc)
looks up an existing extension by ID and upgrades its install location to the
higher-priority policy location. It does not make another ID. Its orphaned
external-extension path then uninstalls unclaimed policy installations.
Thus source evidence predicts **one adopted copy**, and later **uninstallation,
even if originally installed by hand**. Returning to manual management may
require reinstalling Tab-less from the Store. These transitions still need a
real Myoko check; do not claim they were exercised on Simon's installation.
With the default false, this branch leaves his present manual install alone.

## Behaviour

`behaviour.json` retains actual Chromium window/tab/target snapshots.
The real virtual keyboard used the desktop bindings. The middle click used
Chromium's input protocol. Link/popup actions ran in a private local fixture.

| Path | Observed result / limit |
|---|---|
| Ctrl+T | 1 → 2 normal windows, one tab each; system caption and native toolbar retained. |
| Ctrl+N | 2 → 3 normal windows; index-0 exception avoids an extra move. |
| `target=_blank` | 3 → 4 normal windows. Original target remains. |
| Middle click | 4 → 5 normal windows. **The new window gains focus**, despite the background-tab action. The source does not pass `focused: false`. |
| `window.open(..., 'popup,...')` | A native **popup stays a popup**, one tab at index 0. Native origin row retained. `native-popup.png`. |
| OAuth-shaped popup | Cross-origin `127.0.0.1` → `localhost` sign-in fixture stayed a popup; a POST callback returned `state=private-state&code=private-code` through `opener.postMessage`, then closed. No URL close/relaunch. **No real provider/account sign-in tested.** |
| Ctrl+Shift+T | A closed, navigated page window returned: 6 → 7 windows. A blank New Tab is not a valid restore fixture; that earlier probe is not used as passing evidence. |
| Session restore / startup | Restored 9 tabs in 9 windows (8 normal, 1 popup); pinned page retained. A deliberately multi-tab stopped session was split on startup. Focus and strip geometry were not faithfully preserved. This is one clean restart, not a long-term crash/restore claim. |
| Drag-out | Public `windows.create({tabId})` retained the tab in a normal destination. **Real pointer drag not tested.** |
| Drag/attach into another window | Public `tabs.move` left **two tabs in one normal window**. `onAttached` does not run the detach logic. This is not an invariant that every window always contains one tab. |
| Old-window flash | **Not visually established.** Observer timestamps show ordinary new tabs remained attached for about **84–104 ms** before detachment. This is enough to make a flash plausible, not proof of a visible frame. No no-flash claim. |

The first one-window state was captured under Platinum light/dark and Win98
light/dark: `{platinum,win98}-{light,dark}-one-tab.png`. The caption belongs to
our shell. Chromium owns the address/security row and page. Native GTK paint
changed with the private theme. A page's white background need not become dark.

## Vertical tabs in Chromium 153.0.8010.52

| Question | Evidence / answer |
|---|---|
| Available without flags? | **Yes.** Settings shows Tab position, Horizontal / Vertical. The default private profile reports `vertical_tabs.enabled: false`; the capability is available, but vertical placement is **not selected by default**. |
| Feature switch? | `--enable-features=VerticalTabs` alone still reports the placement pref false. At 153, `IsVerticalTabsFeatureEnabled()` accepts `VerticalTabs` **or** default-enabled `VerticalTabsLaunch`. A feature switch is not a preference setter. |
| Declarative preference? | **Yes, first-run seed.** The exact enabled Myoko `initial_preferences` was imported by a fresh private profile without `--no-first-run`; all three vertical prefs and `browser.custom_chrome_frame: false` persisted after exit. `logs/first-run-seed-result.json`. |
| Managed policy? | No vertical-tabs policy was found in the pinned policy definitions. Do not invent one or describe these ordinary prefs as managed. |
| Collapsed width | `outerWidth 1898 - innerWidth 1843 = 55` logical px, about **83 device px at scale 1.5**. This includes the native strip/content boundary. The horizontal strip's removal returned about **40 logical px** of height. Still not caption → toolbar → full-width page. |
| Does collapse persist? | The pref persists, and initial Ctrl+T/Ctrl+N/link windows stayed collapsed. **Session restore is a gap:** 4 of 8 restored normal windows had about 240 px expanded strips; a subsequent restored 40-window shell run had expanded strips throughout. The first-run seed is not an enforcement mechanism. |

`features.json` records default, feature-switch and seeded-profile results.
[`pref_names.h`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/common/pref_names.h)
and [`VerticalTabStripStateController`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/ui/tabs/vertical_tab_strip_state_controller.cc)
explain the limit: the collapse pref is the most recently used state for startup
**without session restore**; restored windows can supply their own state.
No unsupported switch or Chromium patch was added to override it.
The 55 px side strip and restore expansion remain look gaps for a design engineer.

## Memory

Same five public sites and fragments as the earlier popup probe, repeated
1/3/6 times: example.com, example.org, wikipedia.org, nixos.org and Chrome's
extension documentation. Fresh profile each run; 16-second settling period;
Chromium 153, software GL/`--disable-gpu`, nested Hyprland 0.56.2, 2880×1800 at
scale 1.5. Both layouts used collapsed vertical tabs. This measures real
window visibility/viewport/lifecycle costs, not just a window object's bytes.

| Pages | Tabs PSS MiB | Normal windows PSS MiB | Ratio | Hyprland PSS MiB, tabs / windows | Live shm MiB, tabs / windows |
|---:|---:|---:|---:|---:|---:|
| 5 | 562.3 | 1007.5 | 1.79× | 135.9 / 142.7 | 38.3 / 151.3 |
| 15 | 662.3 | 2444.2 | 3.69× | 109.4 / 192.5 | 38.3 / 461.8 |
| 30 | 973.8 | 3719.4 | 3.82× | 117.2 / 332.3 | 38.3 / 693.4 |

At 30 pages the difference is **2746 MiB (2.68 GiB)**. One browser root and one
GPU process remain; renderer counts are 8/18/33 with tabs and 10/20/35 with
the behavioural copy plus observer. PSS sums browser descendants from
`/proc/*/smaps_rollup`; one zero-PSS exited process in the 5-window sample
appears in the raw no-`--type` bucket, not another browser root. All measured
SwapPss values were zero. Host-wide pressure varied, so do not treat one run
as a hardware-independent allocation constant. `memory.json` and
`logs/memory-*.json` retain per-process measurements and loaded URLs.

Live Wayland shm buffer bytes overlap process PSS: **do not add them again**.
Counts were 3 buffers for tabs, versus 15/39/74 for windows. Outer labwc used
about 53–62 MiB. Myoko GPU memory, battery cost and long idle behaviour were
not measured. These numbers are not a new Myoko benchmark.

### Memory Saver is still blocked

Every normal page is the active tab of its own window. At 153,
[`DiscardEligibilityPolicy`](https://github.com/chromium/chromium/blob/153.0.8010.52/chrome/browser/performance_manager/policies/discard_eligibility_policy.cc)
protects `IsActiveTab()` even when the window is not visible. Aggressive Memory
Saver settings do not remove that guard. This is source-verified proactive
eligibility, not a claim based on waiting 16 seconds for automatic discard.
Urgent memory-pressure handling is a different path.

Explicit `chrome.tabs.discard(id)` **did** discard an unfocused sole normal tab
at all three counts. Chromium replaced the tab ID; the probe followed the
returned ID. That external API deliberately bypasses the proactive guards.

Opinion: a separate opt-in helper could discard only windows hidden/minimized
for 10 minutes, excluding audio, capture, pinned tabs and unsaved work, and
reload on activation. Cost: Chromium's native minimized state is not necessarily
our shell's special hidden workspace; an unfocused window can still be visible
on another display; the sole-tab reload needs explicit handling. A timer alone
would lose work or leave blank pages. This is **not a small safe patch**, so no
periodic discard extension or speculative policy ships. Keep fewer page
windows, close finished pages, or retain tabs for high-page-count sessions.

## Twenty and forty windows in our shell

Real sites loaded in a private profile. The shell's actual models were read
through test-only IPC, not substituted with mock windows. The Lua page rules
placed these normal windows on separate pages. Full captures and
`logs/*-{20,40}-shell.json` preserve that layout.

| Surface | 20 windows | 40 windows |
|---|---|---|
| Platinum Control Strip | 900 logical px; all tiles fit | 1780 logical px of a 1920 px screen; all fit, no scroll arrows at this size. Repeated browser icons, titles on hover/menu rather than the strip. |
| Win98 taskbar | 20 shortened title buttons; plan width 57 units per button | 38 icon-only buttons at the 26-unit minimum, Start becomes icon-only, **2 windows in `»` overflow**. Same Chromium icon throughout. |
| Held switcher | — | Real **Super+Tab**: Win98 Cool Switch shows 40 icons and a selected title, and its cycle contains 40 unique window addresses. Platinum cycles **one Chromium app**, not 40 pages. |
| Application menu | One Chromium app group | Chromium row shows **40**; underlying model retains 40 distinct windows, including repeated titles. Opening/scrolling the full submenu was **not** verified; screenshots establish the top-level row only. |

The repository binds Super+Tab. It does **not** bind literal Alt+Tab to Cool
Switch. This probe used the real existing binding; it does not claim Alt+Tab
parity. Source-level cycle tests now cover 20 and 40 same-class windows with
repeated titles, and every window remains in Win98's cycle.

### Ctrl+L collisions

The curated survey contains 19 distinct public URLs plus one fixture. Two
public pages, example.com and example.org, both say **“Example Domain”**.
Thus **2/19 public pages** had a non-unique title in that sample. Wikipedia,
GitHub repository/issues pages, NixOS, Reddit, Hacker News and YouTube had
distinct titles at capture time. This is not an estimate of Simon's daily
collision rate. Opening the same document twice, blank new tabs, sign-in pages
and common error titles can all make it worse.

**Additional matching gap (medium):** three other public pages had `&` in the
native title but `&amp;` in `/json/list` (NixOS home/download and nixpkgs).
Running the existing `cdp-target.js` matcher against those actual captured
clients/targets returned null for them too: **5/19 public pages unavailable in
this survey**, comprising two duplicate-title pages plus three escaped-title
mismatches. `logs/real-title-matcher.json` records the results. This is not
fixed by Tab-less or grouping. The matcher needs a separate, tested title
normalization fix without weakening its unique-target rule; no such fix is
hidden in this evaluation.

The 40-window stress set deliberately added a second copy of every URL. Real
Ctrl+L opened Go to Address / Open under all four theme/appearance combinations;
its actual target was null, it displayed **“Cannot identify this browser
window”**, and Go/OK was disabled. It failed closed. The title matcher was not
weakened to pick an arbitrary page. Use Chromium's own address UI with the shell
integration disabled if repeated titles make this common.

Opinion: optional site groups in overflow/app menus would reduce scanning,
not memory use or CDP ambiguity. They must retain access to every window and
use committed browser origins, not parsed titles. Page favicons and an exact
native-window/target registry are more important than inventing a second app
model. These are design/integration follow-ups; no grouping UI ships here.

## Checks, evidence limits and deployment

Passing focused checks: `chromium-tabless` (enabled/disabled real Myoko policy and
preference assertions plus 20/40-window cycle tests), `chromium-windows`
(existing CDP/key/model and QML lint checks), and `chromium-frame` (existing
migration tests). Run through `/tmp/tandem/remote-check.sh`; no aggregate check.
Nix formatting and `git diff --check` apply to the changed files.

The private runtime used a private HOME, config/state/runtime directory and
D-Bus. The sandbox exposed only `/dev/dri/renderD128`; `AQ_DRM_DEVICES` and
`SEATD_SOCK` named nonexistent paths. Logs reject a Hyprland DRM backend, seat
or libinput device. `logs/{shell,policy-visible}-drm.txt` show **zero open card
nodes**. Cleanup logs and the final process scan show zero session processes.

Still unverified: real Store installation/adoption/removal on Myoko, real OAuth
providers, pointer drag gestures, a high-frame-rate flash recording, narrow
screen overflow, the full Application submenu, and long-term restore/idle
behaviour. The failed source-build/Store probes and first shell-IPC probe are
not successful test results. There is no deployment from this worker. The
parent must enable the option for an opt-in Myoko trial and confirm a single
Store ID before claiming declarative installation complete.

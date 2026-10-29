# Files: a file manager for both desktop themes

Status: design interview complete (2026-10-28), awaiting the owner's confirmation. Nothing is built. The mock is at `/tmp/explorer-mock/` (served at `http://100.114.19.92:8765/explorer-mock/`).

Files is a file manager for Myoko. It shows local files, files on SSH hosts, and libraries in one place. It looks like the Mac OS 8 Finder under Platinum and like Windows Explorer under Windows 98, and follows a live theme switch. Desktop icons come later and use the same model.

## Language

**Place**:
Anything Files can open and list: the local machine, an SSH host, or a library.

**SSH host**:
A machine that Files reaches over SSH from inside the app, with the user's own keys and `~/.ssh/config`. Nothing is mounted.
_Avoid_: mount, remote drive, server (except as the Platinum menu word "Connect to Server…")

**Library**:
A catalog that a service keeps (Pyxis, Ossicle, Comics, Jellyfin), shown as folders of titles with artwork, not as the service's files on disk.
_Avoid_: media library (in the root `CONTEXT.md` that means Jellyfin's imported media on disk, which is a different thing)

**Item**:
One entry in a library: a track, an episode, a book, a comic, a movie. To the rest of the desktop it is a file.

## Decisions

| # | Decision | Reason and cost |
|---|---|---|
| 1 | Files connects to SSH hosts itself. Keys, agent and host config come from the normal SSH places. No mount step, no stored passwords. | The owner does not want to mount anything first. Cost: Files carries its own SSH and SFTP client. |
| 2 | Both themes get the same actions and states. Each theme draws them in its own OS's way. | The tandem rule in `../desktop-themes.md`. |
| 3 | Each theme copies its own OS's layout: one window per folder under Platinum, one Explorer window with a folder tree under Windows 98. | Faithful to each OS. Cost: a copy between hosts takes two windows under Platinum and one under Windows 98. |
| 4 | A new SSH host key needs explicit trust. The safe button (Cancel / No) is the default. | Enter must never trust a key the user did not check. |
| 5 | Libraries in scope: Pyxis (music), Ossicle (podcasts, YouTube, narrated books), Comics (`~/code/sandbox/comics`), Jellyfin. Future work; the design must hold them now. | Owner's list. |
| 6 | A library shows its catalog through the service's API, not its storage on disk. | Names and artwork, not storage paths. Cost: one adapter per service. |
| 7 | Libraries form their own group, apart from machines: a volume icon per library on the Platinum desktop, a "Libraries" branch under Desktop in the Windows 98 tree. | A library is not a machine. |
| 8 | An item behaves as a file. Files does not play or read it. Opening goes through the desktop's normal file handling. | Files stays a file manager; the desktop's handlers decide. |
| 9 | Icons: the service's artwork where its API offers it, or art that Files can generate; otherwise the theme's system icons. | Owner's rule. |
| 10 | Menus stay inside each window under Platinum too, as a menu row under the title bar. The top bar shows the front window's title. | Owner's rule: the top bar only if it works for every toolkit without patching apps. Research (2026-10-28) found no such mechanism on Hyprland. Stock Hyprland has neither `org_kde_kwin_appmenu` nor `gtk_shell1`. The third-party hyprbaric-appmenu plugin plus a registrar would cover Qt 6.9+, GTK3, GtkApplication menubars, Firefox (with prefs) and Chromium. It would still miss Electron/Signal on Wayland, Zed, Tk, Ghostty and libadwaita, and Quickshell has no dbusmenu API (issue #170, PR #484 open). Revisit if Hyprland gains `xdg-dbus-annotation` (wayland-protocols MR !493) or Quickshell PR #484 lands. |
| 11 | Libraries are read-only: browse, open, copy out. No import, rename or delete. | Each service keeps sole control of its catalog. Write actions can come later, one service at a time. |
| 12 | Opening an item follows its handler's `.desktop` entry: a stream URL when the handler takes URLs (`%u`/`%U`), otherwise a download into a size-limited cache and the local path (`%f`/`%F`). | The standard freedesktop rule, so no app needs special support. Cost: two paths and a cache. |
| 13 | A library's folders mirror the service's own top-level sections. | You see what each service calls things. Cost: every library has its own shape. |
| 14 | List view uses columns that fit the kind of item, plus Size where known. | Music: Name, Artist, Album, Time, Size. Episodes: Name, Show, Date, Time, Played. Movies: Name, Year, Time, Size. Comics: Name, Series, Pages, Size. Cost: a column set per kind, in both themes. |
| 15 | Play and read state is shown, never changed. | The service owns it. Cost: Files refreshes it. |
| 16 | An item copied out gets a readable name from the catalog and the original extension (`01 Still Alive.flac` inside `Artist - Album`; `Blade Runner (1982).mkv`). | Titles, not storage names. Cost: naming rules per kind, including characters not allowed in file names. |
| 17 | (Replaced by 31.) Sign in once per library in a themed dialog. The token goes in the desktop keyring (Secret Service). | Period behaviour. Cost: Myoko has no Secret Service provider in the flake today (no gnome-keyring, KeePassXC or oo7 found in `modules/` or `lib/`), so one must be added. |
| 18 | A remote file opened in an app is copied to Myoko. Files watches the copy and uploads it on each save. If the host's copy changed since it was opened, Files asks before it overwrites. | Works with any app, like WinSCP and Transmit. Cost: a change on the host is caught at save time, not as it happens. |
| 19 | Delete on an SSH host moves the file to that host's own freedesktop Trash when it is on the same disk; otherwise Files warns that the delete is permanent. The Trash lists each host's trash as its own group. | Undo for most mistakes. Cost: files on another disk (for example `/srv` on fuji) have no undo. |
| 20 | A copy between two hosts goes through Myoko. | Needs only the keys on Myoko. Cost: slower, and Myoko's network carries the bytes twice. |
| 21 | Transfers belong to Files, not to a window. Closing a progress window does not stop a copy. Platinum: Window ▸ Transfers. Windows 98: a tray icon while copies run. | Cost: copies with no window need a place to find and stop them. |
| 22 | The desktop shows: the files in `~/Desktop`, this machine (Myoko's disk / My Computer), the libraries, and the Trash / Recycle Bin. SSH hosts are not on the desktop. | Owner's choice. The Connect dialog's "Show on the desktop" box is removed. |
| 23 | Find is out of the first design. | It needs remote search and each service's search API. |
| 24 | One "SSH Hosts" folder on the desktop in both themes (Network Neighborhood under Windows 98). Every host is inside it, with its state. | One icon instead of one per host. |
| 25 | Comics gets an "original file" download with Range support in its own server. Until then, Comics items are greyed out with "Not available as a file". | Keeps the rule that an item is a file. Cost: work in `~/code/sandbox/comics`. |
| 26 | Size shows "--" where a service does not report it. Each service gains a size field later. | Honest. Cost: no size sort and no copy total for those libraries yet. |
| 27 | Every folder remembers its window position, size, view and sort, in both themes, for local, SSH and library folders. A remembered window that no longer fits is moved back on screen. | The Platinum spatial Finder; Windows 98's per-folder view setting. |
| 28 | Desktop icons are placed freely and remembered, with Clean Up (Platinum) and Arrange Icons (Windows 98). Icons that fall off screen after a display change come back. | Period behaviour. |
| 29 | Other disks and USB drives: a desktop volume per mounted disk under Platinum, inside My Computer under Windows 98, both with Eject. | Each theme follows its OS. Cost: mount watching through udisks2 and safe unmount. |
| 30 | The Files service runs as a user service from the start of the graphical session. Idle SSH sessions close after a time limit. | Copies outlive windows; desktop icons, Trash and mounts stay live. |
| 31 | Library credentials come from the same sops secrets as Pyxamp (`modules/pyxamp.nix`, `secrets/desktop/<host>.yaml`): a Pyxis token, a Jellyfin API key, none for Ossicle and Comics. A library without its secret does not appear. There is no sign-in dialog. **Replaces decision 17.** | New evidence: Pyxamp already does this, and Myoko has no Secret Service keyring. Cost: a library is added in Nix, not in the app. |
| 32 | Files has its own repository and comes into mountainous as a flake input, like Pyxamp. Its name is Files. | Matches Pyxamp and the flake rule for outside sources. |
| 33 | The first working build covers local files and SSH hosts in both themes: browse, open, copy, transfers, host keys, Trash. Libraries and desktop icons come next. | The owner's first ask. Libraries wait on the Comics change and the client code question. |
| 34 | Files is built on one kit that all of the owner's own themed apps share: the Platinum and Windows 98 drawing and tokens, the service-and-window pattern, and the library clients. Third-party apps keep the native toolkit themes for now and get their own focus later. | The owner wants the best systemic approach as more apps arrive. Cost: the kit is a product of its own; the shell and Pyxamp move onto it. The stack is chosen after the shared-import spike (`/tmp/theme-kit-spike/`). |
| 35 | The kit must cover the controls for the next apps: control panels and settings, media players and remotes, chat, mail and notifications, fleet and host tools. | Owner's list. Viewers, editors and terminal-like apps are not planned. |
| 36 | The kit's Rust parts (service skeleton: socket, protocol, systemd unit; library clients for Pyxis, Ossicle, Jellyfin, Comics) live in their own repository of crates, used by Files and Pyxamp. Pyxamp's clients move there. | One client per service. Cost: a third repository and a Pyxamp refactor. |
| 37 | Pyxamp moves onto the kit first, before Files. | A known app proves the kit early. Cost: Files waits for that move. |
| 38 | Stack: each app is one Rust process with a Qt Quick UI through cxx-qt, drawing with a Quickshell-free Platinum and Windows 98 kit that the shell also uses. Files' always-on service (decision 30) is the app process itself. | A and B tied on performance and pixels; B gives full Qt in one process and does not build apps on a shell-only tool. See `docs/decisions/app-stack.md`. |
| 39 | The kit is curated, not the shell's whole folder: Theme, tokens and shared controls, with no Quickshell imports. The shell imports it too, so there is one copy. | Required by decision 38. Closes the unanswered question about importing the whole folder. |
| 40 | The QML kit lives in the kit repository, beside its Rust crates. Mountainous, Files and Pyxamp all take it as a flake input. | One version for the whole kit; dependencies run one way. Cost: a shell theme change is a kit change plus an input bump, and the parity check must read the kit. |
| 41 | The shell draws the desktop icons with the kit, on its desktop surface. Files supplies the list and handles open, move and drop over a socket. | The desktop stays with the shell and survives a Files restart. Cost: a small shell–Files protocol; the desktop surface takes input. |
| 42 | The kit is named **Hensou** (変装, "disguise": one set of apps that puts on Platinum or Windows 98). Repository `hensou`, QML module `Hensou`, crates `hensou-*`. | Owner chose it after a collision check (crates.io, PyPI, npm, nixpkgs, GitHub, web; `/tmp/name-check/check.sh`): no software product or company found. Rejected for collisions: Henge (HENNGE, a listed Tokyo software company), Bakeru (a Steam game), Henshin (Eclipse Henshin), Mujina, Kawari, Utsuroi, Tanuki, Kitsune, Ruten, Kisekae, Irokae. Replaces the earlier pick, Hotaka. |

## What the library APIs offer today (recon 2026-10-28)

| Library | Reached at | Sign-in | Browse | Original bytes | Size in API | Artwork |
|---|---|---|---|---|---|---|
| Pyxis | `https://pyxis.<tailnet>` | Bearer token plus `x-pyxis-contract` header | Groups/tags, Albums, Playlists (no Artists list) | `GET /stream/:track_id`, Range | No | `artworkUrl` per album and track |
| Ossicle | `https://podcasts.<tailnet>` | None: tailnet identity, same-origin checks | Podcasts ▸ Episodes; recent episodes | `GET /audio/:id`, `/video/:id`, Range | No | `GET /covers/:podcast_id` |
| Comics | `https://reader.<tailnet>` | None: tailnet identity, strict same-origin | Books, Series ▸ Issues | **No.** Only page JPEGs, EPUB parts and narration audio | No | First page image |
| Jellyfin | `https://watch.<tailnet>` | Jellyfin token | Views ▸ Movies, Shows ▸ Seasons ▸ Episodes, Collections | `/Items/{id}/Download`, Range | Yes | `/Items/{id}/Images/{type}`, sized |

Consequences, not yet decided: Comics cannot hand over an item as a file until it serves the original archive. Ossicle and Comics enforce same-origin, so a native client may be refused. Three of four libraries do not report sizes, so the Size column is often empty. Sources: `pyxis/contracts/generated/pyxis.ts`, `pyxis/services/pyxis/src/stream/mod.rs`, `ossicle/services/ossicle/src/api.rs`, `comics/services/comics/src/api.rs`, `modules/media-jellyfin.nix`.

## UI stack findings (recon 2026-10-28, not yet decided)

- Quickshell 0.3.1 `FloatingWindow` is an ordinary toplevel that Hyprland manages (`src/window/floatingwindow.hpp`). Its app_id is per process, so Files would run as its own instance (`qs -c files`), as Pyxamp does (Pyxamp ADR 0005).
- Rust and Quickshell have no direct binding. Pyxamp's pattern works: a Rust process for the logic and a Unix socket carrying JSON lines to `Quickshell.Io.Socket`. `qs ipc` arguments are too small for file lists and fit only triggers.
- 80 of the 128 `Platinum*`/`Win98*` files import `Quickshell`, which is compiled into the `qs` binary. A cxx-qt app could not load them without a stand-in `Quickshell` module. Only a Quickshell UI reuses the shell's own files and the live switch unchanged, and only if Nix delivers the same files into both configs (untested; Pyxamp copied them instead, and the copies drift).
- gtk-rs gets the generated GTK themes for free but not the QML drawing. Slint and iced redraw every control.
- Desktop icons: `DesktopPattern.qml` could draw them, fed over the same socket. Today it takes no input (`mask: Region {}`).

Notes: `/tmp/ui-stack/notes.md`.

### Shared theme files spike (2026-10-28, `/tmp/theme-kit-spike/`)

- A separate Quickshell config **can** use the shell's own theme files without copies. The way that works is a symlink inside the app's config folder (`app/kit -> modules/quickshell`) and `import "kit"` (or `import "kit" as Kit`). Quickshell then makes a qmldir for `kit/` with all 18 singletons. Absolute-path imports, `file:///` imports and `../` paths fail. A Nix-built `Mountainous.Theme` module on `QML2_IMPORT_PATH` also works, with identical pixels.
- A theme switch reaches the app in a median of 15 ms (6–72 ms over 10 switches). Importing the whole shell folder adds about 31 MB (145 → 176 MB).
- Five shell files read files through `Quickshell.shellPath(...)`, which points at the app's folder: `ThemeCatalog`, `PlatinumIconStore`, `Win98IconStore`, `DesktopPattern`, `WebTheme`. Replacing it with `Qt.resolvedUrl(...)` fixes this (`/tmp/theme-kit-spike/shellpath-fix.diff`). The shell's lifecycle test has not run with that fix.
- Each app sets `PlatinumTokens.pixelRatio` itself, and needs qtwebsockets on `QML2_IMPORT_PATH` (because of `CdpBrowser`).
- The shell must not import the shared module as well as its own files: that gives two copies of each singleton.
- Item 4 of the QML structure (no subfolders, no root qmldir) still holds, and now has a cause: Quickshell makes a qmldir only for folders reached by a static import from `shell.qml`. A static `import "sub"` makes later dynamic loads from `sub/` work.
- Pyxamp's "cannot import the bar's files" was untried, not a real limit.

### Stack choice: criteria and evidence in progress

The owner keeps all three stacks open: A (Rust service + Quickshell window), B (cxx-qt with a Quickshell-free kit), C (gtk-rs with the GTK themes). The deciding criteria are **performance at the fidelity already proven**, and **Quickshell's real limits as an application platform**. Evidence being gathered:

- One benchmark for all three (`/tmp/stack-bench/WORKLOAD.md`): 10,000-row list, cold start, PSS, scroll frame times, theme switch, idle CPU, row updates, fidelity screenshots.
- A cxx-qt spike (`/tmp/cxxqt-spike/`).
- A source-based review of Quickshell's limits for apps: windows, menus, text and IME, clipboard and drag and drop, accessibility, lists, D-Bus and portals, hot reload, stability.

### Benchmark results (2026-10-28, `/tmp/stack-bench/`, loaded machine: read as relative)

| Median | A: Quickshell window | B: cxx-qt | C: gtk4-rs |
|---|---|---|---|
| Cold start to rows (ms) | 995 | 1311 | 2992 |
| Memory, PSS (MiB) | 144 | 128 | 160 |
| Scroll p50 / p95 / p99 (ms) | 16.1 / 18.0 / 24.1 | 16.1 / 18.1 / 23.4 | 16.8 / 31.7 / 145 |
| Dropped frames (of about 610) | 8 | 7 | 130 |
| Theme switch (ms) | 44 | 14 | 198 |
| Row update p95 (ms) | 4.1 | 6.5 | 103 |
| Idle CPU | 0 % | 0 % | 0 % |

A and B draw identical pixels (differences of 1/255 on glyph edges). C gets the colours, font and selection right, but rows are 36 px against 24, columns use one font size, headers look disabled, and the scroll bar differs. C's cold start is mostly Vulkan start-up (0.38 s with `GSK_RENDERER=gl`, one probe). A spends 0.5–1.2 s loading the whole shell folder. B needs the shell's kit made Quickshell-free: tokens as `QtObject`, theme file watching moved out of `Theme.qml`, icons read without `FileView`, a per-window replacement for `QsWindow.window` in 36 files (the spike's `Screen` swap is wrong at scale 1.5), and a new menu host, because the shell's menus are layer-shell `PanelWindow`s, not `PopupWindow`s (2–3 days, estimate). cxx-qt's first build took 941 s; it needs Qt merged into one prefix. Evidence: `results-{A,B,C}.md`, `/tmp/cxxqt-spike/kit-edits.diff`.

### Quickshell as an app platform: review (2026-10-28)

Upstream says Quickshell targets shell parts (bars, lock screens, widgets), not application windows, and promises no API stability before 1.0. Findings, with my checks:

| Area | Finding | Check |
|---|---|---|
| Clipboard | Only plain text (`Quickshell.clipboardText`). No file clipboard (`text/uri-list`), no primary selection. | Fits the source cited. A Files service in Rust can own the clipboard instead. |
| Drag and drop with other apps | Reported missing in pure QML. | **Wrong.** Spike (`/tmp/dnd-spike/`, sway headless): with plain QML `Drag.Automatic` + `text/uri-list`, both A and B drag files out to GTK4 and Chromium 153 (Chromium read the file) and accept drops from GTK4. File clipboard: B in-process (about 30 lines of cxx-qt and C++ `QClipboard`); A only through a long-lived owner such as wl-clipboard-rs in the Rust service (a one-shot `Process` lost the clipboard). Hyprland, multi-file drags and MOVE are untested. |
| Modal dialogs | `parentWindow` stacks but does not block the parent. | Plausible; untested. Files can disable the parent itself. |
| Window position | Clients cannot place themselves under xdg-shell. | True for **every** stack on Wayland, not only Quickshell. Restoring positions (decision 27) needs Hyprland rules or IPC in A, B and C alike. |
| Accessibility | Fixed in Quickshell 0.3.2. | Myoko runs 0.3.1, so it lacks the fix until an update. |
| Text and IME | `TextInput`/`TextEdit` and IME work; rich text is Qt's HTML subset; no spell check. | Qt Quick limits; the same in B. |
| D-Bus and portals | No generic D-Bus client; no file chooser portal. | The Rust service can do both (`zbus`, `ashpd`). |
| Single instance | Reported missing. | **Wrong**: Pyxamp already launches with `qs -n -c pyxamp`. |
| Hot reload | File changes reload and drop state unless persisted; production sets `QS_DISABLE_FILE_WATCHER=1`. | Keep state in the Rust service. |
| Memory | About 40–80 MB per instance (inferred). | The benchmark measures it. |

## Open questions

None in the design interview (2026-10-28). Implementation unknowns: a menu host for apps (Qt `Popup` with `popupType: Window` on Hyprland), the per-window Win98 unit at fractional scale, Hyprland rules for restoring window positions, and benchmark repeats on a quiet machine or Myoko.

### New requirement under review (2026-10-28): Android

**Dropped later the same day: no Android builds.** The stack choice is desktop-only again, between B (cxx-qt) and E (Slint). Kept below for the record.

Can Slint draw the shell too (research, 2026-10-28)? **Not in 2026.** Slint has no official layer-shell support (discussions #1765, #6910). Community platform shims (`spell-framework`, `layer-shika`) are alpha, and no production Slint shell exists. So with E the shell stays on QML and each theme lives in two copies for the foreseeable future. Also relevant to apps: Slint's built-in `PopupWindow` draws inside the window, so menus near a window edge are clipped unless custom Wayland popup code is added.

The owner may want some apps on Android too, from the same Rust code, starting with a Rust client for Forgerie (today a browser app). Dioxus is the candidate he named. This may reopen decision 38 for apps that must run on a phone. Research on Dioxus, cxx-qt, Slint and Tauri on Android is running. Step 1 waits until this settles, because it decides what Hensou's drawing is written in.

Research result (2026-10-28):

| Stack | Linux desktop | Android | Nix toolchain | Theme kit |
|---|---|---|---|---|
| cxx-qt 0.10 | Qt Quick (chosen, decision 38) | Not tested or supported by KDAB | No Qt 6 for Android in nixpkgs; needs an FHS environment or a source build | Reuses the QML kit (after the Quickshell-free refactor) |
| Dioxus 0.7 | WebKitGTK webview; native Blitz renderer is beta | Android WebView, experimental; no notification, background, file-picker or back-button APIs without Kotlin/JNI | `androidenv` + Gradle | Port to CSS |
| Tauri 2 | WebKitGTK webview | Stable, with official plugins (notifications, files, deep links, back button) | `androidenv` + Gradle | Port to CSS |
| Slint 1.18 | Native (Skia/FemtoVG) | Supported since 1.5 | `androidenv` + `cargo-apk` | Redraw in `.slint`; has physical-pixel units (`phx`) for exact bevels |

Owner's answers (2026-10-28): on the phone a kit app has a **plain phone-native look**; the retro themes are desktop only. Only the **Forgerie client** needs a phone version. **One stack for every app**, even if desktop fidelity or speed drops a little. Consequence: cxx-qt cannot be that stack (no Android path under Nix), so **decision 38 is reopened**. The candidates are Tauri 2 or Dioxus (webview, kit in CSS) and Slint (native, kit redrawn). Either way the shell keeps its QML, so each theme exists twice (QML for the shell, CSS or Slint for apps) and the parity rule must compare them. A benchmark of a webview (D) and Slint (E) on the same workload is running.

Benchmark, columns D and E (2026-10-28, `/tmp/stack-bench/results-{D,E}.md`, `logs/table-all.md`). E is Slint 1.18.1 (winit, femtovg), 3 runs per measure: cold start **254 ms** (A 995, B 1311), PSS **55.7 MiB** (A 144, B 128), scroll p95/p99 20.8/24.7 ms with 8 dropped frames (A 18.0/24.1, 6), scroll CPU 40 % (A 61), theme switch 13 ms (light/dark 8.5, platinum/win98 44). Fidelity against A: same device pixels for bevels, rules, selection and scroll well; text is greyscale-antialiased instead of A's subpixel colour, about 1 device px lower in some rows; icons are fixed PNGs. First build 41.5 min under load, rebuild 48 s. D (wry on WebKitGTK) built but drew a blank window in headless sway (WebKit reported a negative width and pixel ratio); **no webview numbers**, cause unknown.

My checks: the QML kit already snaps bevels to device pixels at 1.5 (the shell does it today), so the research's "QML needs pixelAligned or 9-patches" does not apply. "100% reuse" for cxx-qt is too strong: it reuses the kit after the Quickshell-free refactor. The CSS route is not new ground: the mocks and `themes/*/web.css` already draw both themes in CSS, but not yet at the shell's fidelity. Webview performance on the 10,000-row workload is not measured.

## Order of work

1. Hensou: create the repository; move the shared QML out of the shell, Quickshell-free; move Pyxamp's library clients into crates; the shell imports Hensou.
2. Pyxamp moves its face onto Hensou (decision 37).
3. Comics serves original files (decision 25), in parallel.
4. Files, first build: local files and SSH hosts in both themes (decision 33).
5. Then libraries, then desktop icons.

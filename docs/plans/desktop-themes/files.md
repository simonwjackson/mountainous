# Files: a file manager for both desktop themes

Status: design interview in progress (started 2026-10-28). Nothing is built. The mock is at `/tmp/explorer-mock/` (served at `http://100.114.19.92:8765/explorer-mock/`).

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

## Open questions

Tracked in the interview; this list moves into the decisions table as each one settles.

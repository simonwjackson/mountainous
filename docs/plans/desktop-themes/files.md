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
| 10 | Platinum's app menus go in the top bar only if a systemic mechanism works for every toolkit without patching each app. Otherwise menus stay inside the window. | Owner's rule. Feasibility on Hyprland is being researched. |
| 11 | Libraries are read-only: browse, open, copy out. No import, rename or delete. | Each service keeps sole control of its catalog. Write actions can come later, one service at a time. |
| 12 | Opening an item follows its handler's `.desktop` entry: a stream URL when the handler takes URLs (`%u`/`%U`), otherwise a download into a size-limited cache and the local path (`%f`/`%F`). | The standard freedesktop rule, so no app needs special support. Cost: two paths and a cache. |
| 13 | A library's folders mirror the service's own top-level sections. | You see what each service calls things. Cost: every library has its own shape. |
| 14 | List view uses columns that fit the kind of item, plus Size where known. | Music: Name, Artist, Album, Time, Size. Episodes: Name, Show, Date, Time, Played. Movies: Name, Year, Time, Size. Comics: Name, Series, Pages, Size. Cost: a column set per kind, in both themes. |
| 15 | Play and read state is shown, never changed. | The service owns it. Cost: Files refreshes it. |
| 16 | An item copied out gets a readable name from the catalog and the original extension (`01 Still Alive.flac` inside `Artist - Album`; `Blade Runner (1982).mkv`). | Titles, not storage names. Cost: naming rules per kind, including characters not allowed in file names. |
| 17 | Sign in once per library in a themed dialog. The token goes in the desktop keyring (Secret Service). | Period behaviour. Cost: Myoko has no Secret Service provider in the flake today (no gnome-keyring, KeePassXC or oo7 found in `modules/` or `lib/`), so one must be added. |

## Open questions

Tracked in the interview; this list moves into the decisions table as each one settles.

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

## Open questions

Tracked in the interview; this list moves into the decisions table as each one settles.

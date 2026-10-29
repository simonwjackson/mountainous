# Owner apps: Rust and Qt (cxx-qt) on a Quickshell-free theme kit

Status: accepted 2026-10-28. Applies to Simon's own themed apps: Files first, then Pyxamp, settings and control panels, media players and remotes, chat and mail, fleet tools. Third-party apps keep the native GTK, Qt and web themes.

Each app is one Rust process with a Qt Quick UI through cxx-qt. Its QML draws with the same Platinum and Windows 98 kit that the Quickshell shell uses, so an app matches the shell pixel for pixel and follows the live theme switch. The kit has no Quickshell imports. Each host feeds it the theme state: a Rust watcher in an app, a `FileView` feeder in the shell.

## Why

Performance did not decide it. On one 10,000-row list workload, a Quickshell window fed by a Rust service (A) and a cxx-qt app (B) tied: scroll p95 18.0 against 18.1 ms, about 7 dropped frames of 610, identical pixels. B used 16 MiB less memory and switched theme in 14 ms against 44. gtk4-rs (C) lost on both counts: 130 dropped frames, a p99 of 145 ms, a 3 s cold start, and a visibly different drawing. What decided it: Quickshell's authors scope it to shell parts, not applications. Its API is pre-1.0. It exposes only a plain-text clipboard and no modal windows. A needs two processes and a socket protocol for every app. B gets full Qt in one process.

## Considered options

- **A: Rust service + Quickshell window over a Unix socket.** It needs a 5-file shell fix and works today. Rejected as the base for many apps for the scope and plumbing reasons above.
- **C: gtk4-rs with the generated Mountainous GTK themes.** Rejected: slower, and never an exact match with the shell.

## Consequences

- The shell's shared parts move into a Quickshell-free kit:
  - the token singletons become `QtObject`;
  - theme file watching moves out of `Theme.qml` into a shell-only feeder;
  - icons are read without `FileView`;
  - 36 files that use `QsWindow.window` for the Win98 unit get a per-window replacement. `Screen` is wrong at scale 1.5.
- The shell's flat-file, no-root-qmldir rule (`docs/plans/desktop-themes.md`, QML structure item 4) still holds. The kit loads in Quickshell as flat files, as a directory import or as a module.
- Apps need their own menu host, because the shell's menus are layer-shell `PanelWindow`s. The plan is Qt 6.11 `Popup` with `popupType: Window`; whether it makes a real `xdg_popup` on Hyprland is untested.
- Builds: cxx-qt 0.10 is pre-1.0 and not in nixpkgs. It needs Qt merged into one prefix (`qt6.env`). The first build took 941 s.
- Pyxamp's face moves off Quickshell onto the kit, before Files.
- Window positions are not the app's to set under xdg-shell, in any stack. Restoring them needs Hyprland rules or IPC.

Evidence: `/tmp/stack-bench/` (results and harness), `/tmp/cxxqt-spike/` (`kit-edits.diff`), `/tmp/theme-kit-spike/`, `/tmp/dnd-spike/`. The design record is `docs/plans/desktop-themes/files.md`.

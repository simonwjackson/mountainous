# Desktop lock

`modules/lock.nix` installs hyprlock, its PAM service, hypridle and
`mountainous-lock` in the desktop layer. Super+L asks logind to lock the
session. The Apple-menu actions are not connected yet.

## Policy

- Lock after 300 seconds idle, and before sleep.
- `inhibit_sleep = 3` waits for Hyprland's lock notification before sleep.
- Blank displays 30 seconds after the compositor confirms a lock, including
  a manual lock. Unlock cancels this delay.
- After waking a locked display, blank it after another 30 seconds idle.
- Suspend after 900 seconds idle only if a battery reports `Discharging`.
  Recheck the battery condition every 60 seconds. Idle inhibitors still apply.

The first blank uses a systemd oneshot service. A plain 30-second hypridle
listener measures idle time, not time since locking. It would blank 10 seconds
into a manual lock requested after 20 seconds idle. The listener therefore
waits until the oneshot has finished before it can blank subsequent wakes.

This replaces `oled-idle`'s five-minute blank and resume behavior. Its immediate
pre-sleep blank is deliberately superseded by lock-before-sleep. If suspend is
delayed, the new lock-relative delay still blanks the display.

## Appearance and fallback

The wrapper reads the existing `mountainous/theme` and `theme-extra` files
under `$XDG_STATE_HOME` (default `~/.local/state`). Light ignores extra-dark.
Dark defaults to grey; dark with extra-dark enabled uses pure black and the
compact dialog. Windows 98 currently uses the same Platinum dialog.

ChicagoFLF dialog PNGs are built at scales 1, 1.25, 1.5 and 2. The live field,
date and attempt count share the PNG generator's geometry. Other scales use
the nearest native-size PNG without resampling. Very small outputs can clip
the compact dialog; keyboard input still reaches hyprlock.

The focused output and every `eDP-*` laptop output show the dialog. Other
outputs show only Peaks (or black in extra-dark). Output selection happens
once at lock time. An unplugged focused output cannot hide the panel dialog.

The wrapper uses `$HYPRLAND_INSTANCE_SIGNATURE`, never a guessed compositor.
It serializes requests, writes config atomically and falls back to static,
monitor-independent config if configuration or hyprlock fails. A locker crash
can restart the fallback; it does not unlock the session.

## First-deploy recovery

Before testing on Myoko, keep an authenticated text console and a trusted
remote administration channel available. Do not rely only on Super+L: normal
keybindings are blocked while a session lock owns input. Kanata also remaps
Ctrl, Alt and the function keys; verify access to the text console first.

From Simon's text console:

1. Run `loginctl list-sessions` and identify the graphical session, not the text
   console session.
2. Run `systemctl --user restart hypridle`, then
   `loginctl lock-session <graphical-session-id>`. With
   `misc.allow_session_lock_restore = true`, a new locker can replace a crashed
   locker. PAM authentication is still required.
3. If the theme path fails, run `mountainous-lock` with
   `--monitors-json /dev/null` from the graphical session's environment. Invalid
   JSON deliberately selects the static fallback. Inspect the imported values
   with `systemctl --user show-environment`; do not guess the Wayland socket or
   compositor signature when launching from a text console.
4. If replacement still fails, save work through other channels if possible,
   then terminate only the graphical session with
   `loginctl terminate-session <graphical-session-id>`. This loses unsaved work
   and returns to the greeter. Do not try to bypass the lock by killing hyprlock.

Disabling hypridle stops automatic locking, including the sleep policy. Treat
that as an explicit temporary security reduction, not a normal recovery state.

## Focused checks

Use `checks.x86_64-linux.lock-config`, `lock-art` and `lock-policy` separately.
The last checks the evaluated Myoko configuration, including PAM and removal
of `oled-idle`. `packages.x86_64-linux.mountainous-lock` is a native wrapper
build target. `system.build.mountainousLock` is the host-configured wrapper.
Follow AGENTS.md's resource limits; never run `nix flake check`.

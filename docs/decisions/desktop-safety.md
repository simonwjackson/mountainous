# Quickshell restart safety

The desktop owns chrome, not application lifetime. `Launcher.qml` owns all
Quickshell application launches and recent-app state. `Heartbeat.qml` owns the
systemd watchdog. Neither depends on the optional Chromium theme feature.

## Launcher contract

- `launch(argv: list<string>, meta)`, where `meta` is `{id, name, icon, kind}` and
  `kind` is `app`, `webapp` or `command`.
- `launchEntry(entry)` takes a Quickshell `DesktopEntry`. It uses `entry.command`
  (Quickshell's parsed argument list), `entry.id`, name and icon. It honours
  `workingDirectory` through `env --chdir=…` and `runInTerminal` through Ghostty.
  It never calls `entry.execute()` or parses `execString` with a shell.
- Read-only property `recent` contains at most ten
  `{id, name, icon, kind, argv, lastLaunched}` records, newest first.
  `lastLaunched` is Unix time in milliseconds. The pair `(kind, id)` identifies
  a recent app. Commands are not recorded.

A launch invokes this argument vector, without a shell:

```
env -u NOTIFY_SOCKET -u WATCHDOG_USEC -u WATCHDOG_PID
  systemd-run --user --scope --slice=app.slice --collect --quiet
  --expand-environment=no --unit=app-<sanitized-id>-<nonce> -- <argv…>
```

The scope is independent of `quickshell.service`; it has no `PartOf` dependency
on the shell. Sanitization applies only to the unit name, never application
arguments. `--expand-environment=no` also prevents systemd from interpreting
literal dollar signs. Clearing notify/watchdog variables prevents launched apps
from inheriting the shell's watchdog contract. The scope inherits the graphical
session environment from the launching process rather than relying on a possibly
stale user-manager environment.

Nixpkgs also packages `app2unit` (the inspected package is 1.4.4). It launches
Desktop Entries as user units, and includes terminal and open helpers. It is a
useful general desktop-entry launcher. Here Quickshell already supplies the
parsed command and metadata, and `systemd-run` is already installed for the
watchdog. Calling systemd directly avoids another desktop-entry parser and
runtime dependency. The cost is that Launcher owns the small unit-name,
terminal and working-directory adapter.

History is `$XDG_STATE_HOME/mountainous/recent-apps.json`, with the standard
`$HOME/.local/state` fallback. FileView uses synchronous first reads and atomic,
blocking writes, so a restart sees either the old complete JSON or the new one.
Missing, corrupt and invalid records yield an empty/filtered list. Startup makes
the state directory before the first pending write. History records launch
requests, not application readiness; an executable or systemd failure can still
leave a recent item. Arguments, including web URLs, are stored locally as given;
callers must not put secrets in launch arguments. No cross-process history merge
is promised: one Quickshell instance owns this state.

The changed launch sites are OmniBar app selection and its terminal command,
both CdpBrowser web-app paths, and Win98 Programs. Platinum's current dock only
activates existing windows; it has no application-launch path to replace.
Short-lived compositor, theme, screenshot and other helpers stay unchanged.

## Heartbeat and optional feature boundary

The root instantiates `Heartbeat` directly. Its Timer runs every 500 ms and
starts `systemd-notify` only when the previous ping has exited. The first ping
sets `WATCHDOG_USEC=2000000`; the unit keeps a 20-second startup allowance,
`NotifyAccess=all`, `WatchdogSignal=SIGKILL`, `Restart=on-failure` and
`RestartSec=2`. With no `WATCHDOG_USEC`, the component does nothing.

`OptionalWebTheme.qml` is an asynchronous filename Loader for `WebTheme.qml`.
WebTheme is now a normal Scope, not a singleton referenced from a root binding.
A missing import/type stays behind that Loader and produces an explicit error
log. The shell contains no reference to the optional WebTheme symbol. A broken
feature leaves Chromium pages unthemed; it does not stop watchdog pings.

## Generation linking

The generation-43 timestamps are consistent with an incomplete Hjem link pass,
but do not prove the cause of that ReferenceError. The pinned Hjem module
(`modules/nixos/base.nix`, input e5e30b4320a8cbcd6cdfc65f044763669a8f0363)
orders system `hjem-reload@%i.service` after, and requires,
`hjem-activate@%i.service`. The activation links the complete manifest; the
reload phase then handles user-unit reload actions.

`bars.nix` adds an `ExecStartPost` to that reload phase. It acts only for Simon,
checks for a user bus, and restarts an active or failed Quickshell after resetting
its failure/start-limit state. It leaves a manually stopped/inactive shell alone.
A user unit cannot order itself after a system-manager unit; adding
`After=hjem-activate@…` to Quickshell would not establish this ordering.
A source restart trigger alone would change when Nix requests a restart, not
order that restart after Hjem has finished. The hook therefore establishes the
explicit completion boundary instead of relying on file watching.

Cost: Hjem activations can restart the bar even when unrelated home files
changed. A running optional WebTheme failure can remain unavailable until a
reload or restart. This hook has not been deployed as part of this work.

## KillMode backstop

Keep declarative `KillMode=process`, in addition to independent app scopes.
This preserves applications started by older generations in the service cgroup
and protects against an external helper starting an unexpected long-lived app.
`mixed` is not an app-survival backstop: its final SIGKILL still targets the
remaining cgroup. `control-group` would clean up all helpers but also kill those
legacy applications.

Cost: a stuck helper can outlive Quickshell. Its normal helpers are short-lived,
but systemd no longer guarantees cgroup-wide cleanup on restart. The app scopes
remain the primary lifetime mechanism, not this exception. Reconsider
`control-group` only after legacy processes are gone and every external launch
path is known to use an independent scope. Ending the full user session can
still end its applications; this change promises restart safety, not logout
survival.

## About / configuration revision

`modules/desktop-safety.nix` captures flake-parts' existing outer `self` and sets
`system.configurationRevision = lib.mkDefault (self.rev or self.dirtyRev or null)`
in the shared desktop layer. No new NixOS special argument is needed.
`nixos-version --configuration-revision` and `nixos-version --json` consume this
NixOS setting. Dirty source is explicitly marked by `dirtyRev`; a non-Git source
without either value reports no revision rather than inventing one.

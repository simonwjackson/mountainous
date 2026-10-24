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

The systemd-run scope transport itself uses `XDG_RUNTIME_DIR` to locate the
user manager. Production inherits `/run/user/1000` on Myoko, not a private
preview directory. A NixOS assertion rejects a conflicting global/service
runtime override; the recorder check also verifies UID 1000 and no override.
Launcher does not set or unset this variable. A nested preview deliberately has
a different graphical runtime, so its test-only systemd-run adapter routes the
manager connection through `/run/user/1000` and restores the private runtime
inside the scoped command. That adapter is not shipped in production.

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

## KillMode and legacy-app transition

Use declarative `KillMode=mixed`. Launcher apps live in independent app.slice
scopes, not quickshell.service's cgroup. On a normal stop, systemd sends SIGTERM
to the main process, then kills remaining service-cgroup helpers when the main
process exits (or the stop timeout expires). On a watchdog SIGKILL the main
process cannot clean up its children, so systemd's final cgroup cleanup matters.
This covers `pw-record`, whose 180-second limit otherwise lives in a QML Timer,
and a stuck `systemd-notify`. Scoped apps are outside that cgroup.

Cost: an application still in the bar's cgroup is a leftover too and will die.
An in-progress dictation take can be lost when the shell is killed. Unlike the
previous `process` backstop, mixed does not permit arbitrary helper orphans.
Ending the full user session can still end its applications; the guarantee here
is restart safety, not logout survival.

### Which drop-in wins

The NixOS unit generator (`nixos/lib/systemd-lib.nix`, `generateUnits`) calls
its generated drop-in `overrides.conf`. The default strategy is
`asDropinIfExists`: it writes a complete unit if there is no upstream unit,
otherwise that drop-in. The existing realized user-unit tree inspected here has
a complete `quickshell.service`; the strategy is also captured by the focused
recorder check. Do not assume a future upstream/package unit cannot turn this
into a drop-in.

When both named drop-ins exist, the result is unambiguous:

| File | Setting | Result |
|---|---|---|
| `/run/systemd/user/quickshell.service.d/deploy-3-preserve-apps.conf` | `process` | Read first |
| `/etc/systemd/user/quickshell.service.d/overrides.conf` | `mixed` | Read later; wins |
| `/run/systemd/user/quickshell.service.d/zz-deploy-preserve-apps.conf` | `process` | If installed, read last; wins |

Different basenames sort lexicographically across directories. Directory
priority (`/etc` over `/run`) resolves *identical* basenames; it does not stop a
later-named runtime file from winning. Any drop-in overrides the base unit.
`tests/quickshell-dropin-order.sh` exercises systemd's own offline configuration
loader for all three cases, without changing a live user manager.

### Exact preservation step before the approved switch

An operator must run this **on Myoko as root, before any switch, daemon reload
that loads mixed, or Quickshell restart**. Do not remove the existing runtime
file yet. This work does not execute these commands or deploy:

```sh
set -eu
install -d -m 0755 /run/systemd/user/quickshell.service.d
printf '[Service]\nKillMode=process\n' > /run/systemd/user/quickshell.service.d/zz-deploy-preserve-apps.conf
chmod 0644 /run/systemd/user/quickshell.service.d/zz-deploy-preserve-apps.conf
uid=$(id -u simon)
as_simon() {
  runuser -u simon -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" "$@"
}
as_simon systemctl --user daemon-reload
test "$(as_simon systemctl --user show quickshell.service --property=KillMode --value)" = process
as_simon systemctl --user cat quickshell.service
```

Only after that check passes, run the normal approved `nixos-rebuild switch`
from the tested checkout. The late runtime file remains present while Nix and
Hjem activate/restart the shell, so already-running legacy apps keep their
process-only protection. After the switch, run the same `show` check again; it
must still say `process`, not `mixed`.

Prefer leaving both runtime files until the next planned reboot. A reboot ends
legacy apps and removes `/run` overrides; new Launcher apps then use independent
scopes and the declared mixed policy applies. During this transition, helper
cleanup still has the old process-only limitation.

To enable mixed without a reboot, first close **all legacy GUI applications
still in quickshell.service's cgroup**. Inspect the unit's cgroup/status; a
window's existence alone does not show its cgroup. Then, as root with the same
`as_simon` function, remove only these two known transition files and reload:

```sh
rm /run/systemd/user/quickshell.service.d/deploy-3-preserve-apps.conf \
   /run/systemd/user/quickshell.service.d/zz-deploy-preserve-apps.conf
as_simon systemctl --user daemon-reload
test "$(as_simon systemctl --user show quickshell.service --property=KillMode --value)" = mixed
```

No immediate restart is needed. Do not remove the protection while legacy apps
remain: the next restart or watchdog kill would terminate them.

## About / configuration revision

`modules/desktop-safety.nix` captures flake-parts' existing outer `self` and sets
`system.configurationRevision = lib.mkDefault (self.rev or self.dirtyRev or null)`
in the shared desktop layer. No new NixOS special argument is needed.
`nixos-version --configuration-revision` and `nixos-version --json` consume this
NixOS setting. Dirty source is explicitly marked by `dirtyRev`; a non-Git source
without either value reports no revision rather than inventing one.

## Verification

The focused tests exercise argv preservation, missing/corrupt/full recent-app
state, actual FileView repair/persistence, and heartbeat pings with a broken
WebTheme. The recorder check also asserts `KillMode=mixed`, UID 1000 and no
runtime override, prints the evaluated Myoko unit/revision/toplevel, and runs
the offline drop-in ordering test. The new pure launcher test checks that the
launch prefix neither sets nor unsets `XDG_RUNTIME_DIR`.

A real private Hyprland proof ran at 2880x1800, scale 1.5, with a transient
`safety-quickshell-mixed.service` mirroring the watchdog, restart and kill-mode
settings. It used the production shell, Launcher, Heartbeat and optional Loader,
with only test IPC and a non-recording lingering helper added to the staged copy.
The helper ignores SIGTERM/SIGHUP and clears its parent-death signal, so a QML
limit or parent-death cleanup cannot explain its death after a watchdog SIGKILL.

| Event | Observed result |
|---|---|
| Launch through Launcher | Foot PID `1756994` in `app.slice/app-safety-mixed-mvmp52qx-1-sseviz94.scope`; its actual argv[0] and kernel cgroup were checked |
| Restart test Quickshell | Bar `1756930` → `1757091`; app PID unchanged/alive; old helper `1756945` killed |
| SIGSTOP bar beyond the 2-second watchdog | systemd killed `1757091`, killed helper `1757105` with SIGKILL, then started bar `1757288`; app PID unchanged/alive; `NRestarts=1` |
| Broken WebTheme | Bar PID `1757343` remained alive past the 20-second startup allowance; app PID unchanged/alive; bar still visible |

The native scope status, PID/cgroup snapshots, journal and screenshots are in
`/tmp/safety/mixed/`; the complete passing transcript is
`/tmp/safety/mixed-budget-3-proof.log`. No microphone was opened.

### Harness corrections and safety

The earlier reference harnesses used DRM backends. They were not copied in that
respect. The successful setup keeps `LIBSEAT_BACKEND=seatd`, a nonexistent
`SEATD_SOCK`, and a nonexistent `AQ_DRM_DEVICES`. Render-node offscreen rendering
is allowed; no modesetting `card*` descriptors were observed, and neither log
contained `drm: Starting backend`.

The successful launch setup copies the references' setsid/stdin handling,
private D-Bus, and create/configure/disable order. Unlike the failing software-only
startup, it initially enables WAYLAND-1 at `mode="preferred"`, creates and
configures HEADLESS-1 at 2880x1800/1.5, and only then disables WAYLAND-1. The
combined setup fixed startup; the individual launch-variable changes were not
A/B tested separately.

Two later harness problems were diagnosed before retrying:

- Scope transport failed because the graphical fixture's private runtime lacked
  the user manager's socket. The test-only argv adapter uses the real manager
  runtime for systemd-run and restores the private runtime inside the scoped
  command. Production inherits the real session runtime and needs no adapter.
- A broad `pgrep -f` matched the Python diagnostic adapter because its command
  line contained the foot arguments. The final proof reads the scope's
  `cgroup.procs` and matches argv[0] exactly to the foot executable. A pure test
  rejects the wrapper case. The kernel cgroup check therefore describes the
  application, not a launcher parent.

The proof and focused builds hold the shared heavy lock only while running,
pass the 60-second memory/swap gate, and use nice 10. All private proof processes
and test scopes were stopped. Nothing was deployed, landed or pushed. Full
check logs and the final evaluation are indexed by `/tmp/safety/REPORT.md`.

# App profiles and fleet preferences

Pi is an app profile, not a system package. Each host exposes
`/nix/var/nix/profiles/apps/pi/bin/pi` on PATH. Unzen updates that profile
at 00:00, 06:00, 12:00 and 18:00 UTC without a system rebuild. The updater
never changes CLIProxyAPI or the decision gateway.

## Pi runtime

The profile uses `inputs.pi.packages.<system>.coding-agent-bun` without a
SettingsManager patch. Pi uses its normal `~/.pi/agent` directory. Auth,
sessions and installed package files stay local.

The wrapper loads CLIProxyAPI and `pi-decide.ts` with explicit `-e` paths.
It reads the two API keys from runtime sops files owned by simon, mode 0400.
It supplies `CLIPROXYAPI_BASE_URL`, `CLIPROXYAPI_API_KEY` and
`PI_DECIDE_API_KEY`. No key enters the Nix store or a command argument.
All eight hosts receive the decision gateway master key. This includes admin
rights and spending authority. Rotate both fleet.yaml and Rakku's gateway
secret together. No gateway-module change is part of this feature.

Each run gets a private mode-0700 TMPDIR. The provider uses a predictable
import filename, so sharing /tmp would allow another user to supply code.
Normal exits remove the directory. SIGKILL can leave it behind.

`PI_OFFLINE=1` suppresses pi's startup network checks and missing-package
auto-installs. Provider model discovery and inference still use the network.
The wrapper does not set `--provider`, `--model` or `--no-extensions`.
Local package discovery remains enabled. Missing local packages are skipped.
Remote-only packages and portable package installation are deferred.

## Writable preferences

`~/.pi/agent/settings.json` is a symlink to
`~/.local/share/fleet-sync/pi/settings.json`. Nix creates directories and the
link, but never writes settings. The tmpfiles `L` rule does not replace an
existing file. Migrate an existing file explicitly, retaining a backup.

Syncthing shares the whole settings file, including `defaultProvider`,
`defaultModel`, `enabledModels` and `packages`. Nix does not merge or lock
any field. Only settings.json is allowed. Auth, sessions, lock files and
package contents do not sync. There are five versions of incoming changes.
Simultaneous edits can create conflict copies. Offline hosts sync after they
reconnect. File changes normally propagate in seconds, not synchronously.
Existing pi sessions can retain settings in memory. Start a new session to
use a default changed elsewhere. Project settings and explicit CLI choices
can override the global default.

Seed the file on one host only. A fresh host waits for that file, and before
it arrives pi uses its normal model fallback. The wrapper registers both
providers, so that fallback does not guarantee CLIProxyAPI or a particular
model. Keep `defaultTools = [ "+codemode" ]` in the shared preferences to use
classify() through codemode. Nix no longer enforces that choice.

Fuji keeps local pi settings because its builder-only contract forbids
Syncthing. Zao is not a fleet host and is not a sync peer.

## Declarative trust

`modules/fleet-sync.nix` owns the Syncthing configuration. A folder declares
its hosts and allowed top-level file names under `mountainous.fleetSync`.
All members must have identities before deployment. There is no manual device
or folder acceptance.

Run `./scripts/fleet-sync-enroll --all` once to enroll the seven pi peers.
A rerun keeps existing identities. The script encrypts the cert and key in
`secrets/hosts/<host>.yaml` and records public IDs in
`deploy/fleet-sync-devices.json`. Stage new files before Nix evaluation.
Host files are encrypted to the operator and that host only. No trust comes
from the GUI. Identity rotation is a separate, explicit operation.

Global/local discovery, relays, NAT traversal, introducers, auto-accept and
Syncthing auto-upgrades are off. Peers use fixed tailnet DNS addresses on
TCP 22000. The firewall opens that port only on tailscale0. The GUI and API
use a private Unix socket. The NixOS module applies devices and folders via
that socket and removes entries absent from the repo. A small ExecStartPre
step sets the network policy before the daemon starts. Without that step,
the upstream module permits factory-default discovery and relays until its
REST update runs. Tate exposed a two-second window during the first switch.

## Updater preparation and limits

Unzen's deploy and Fuji-builder SSH keys and signing key live in
`/var/lib/app-updater`. Only public halves are committed. The app-deploy
account can write app profiles, not system profiles. The Fuji builder key
is restricted to `nix-daemon --stdio`. Deploy-rs verifies signatures and
provides app-scoped rollback.

The updater uses a fixed, clean source checkout at
`/var/lib/app-updater/repository`. It never pulls mountainous or commits a
new lockfile. It builds candidate input revisions with `--override-input`,
checks the app version and deploy schema, then records per-host results.
Failures on one host do not prevent other hosts from updating. Partial
failure exits nonzero and retries on the next run. Private receipts are
stored under `/var/lib/app-updater`.

Create `/var/lib/app-updater/enabled` only after the first signed app deploy
works. Until then the service's condition keeps the timer from deploying.
Unzen's boot partition currently has I/O errors. Do not reboot or attempt a
persistent system switch until that fault is repaired. Hiyori is offline
and its SSH host pin is still missing. Myoko requires a Tailscale SSH check.
The first aarch64 app build is not yet complete and needs Fuji.

## Add another app or sync folder

Add a flake input and set `mountainous.appProfiles.<name>.package` to a
system-to-package function. Declare `mountainous.appUpdates.<name>` on Unzen
with its input, schedule and target hosts. An optional hostModule supplies
runtime hooks. The package must have a version and `bin/<name> --version`.

A service that needs preference sync declares
`mountainous.fleetSync.folders.<name> = { hosts = [ ... ]; files = [ ... ]; }`.
Its data lives under `/home/simon/.local/share/fleet-sync/<name>`. This
mechanism syncs files for simon. It does not manage service-database migration
or guarantee a single writer.

## Focused verification

Build `.#checks.x86_64-linux.app-pi`, `.#checks.x86_64-linux.app-profiles`
and `.#checks.x86_64-linux.fleet-sync`. The latter evaluates trust, network
and file allow-list policy across all hosts without a VM.

`tests/fleet-sync-smoke.py --agent <upstream-agent-store-path> --settings <json>`
runs two local Syncthing processes using the evaluated pi folder/options.
It tests pi's shipped SettingsManager writing through the link, model and
scope changes in both directions, exclusion of auth.json, and startup logs
without discovery, relays or QUIC. Use `--syncthing <binary>` and
`--runtime <bun>` to select the pinned host package and pi runtime. It does
not contact the fleet or make inference requests. Full-suite and VM runs
are not required for this rollout.

## Rollout evidence, 2026-10-15

The initial activation covered Tate only. Its system closure is
`/nix/store/83w13qw1kbph0flk212qm8j16qjpmmwi-nixos-system-tate-26.11.20260923.4975466`.
Its pi app is `/nix/store/ln71b223zhn6snihmxgrhnqadd1cgsv6-pi`, version 1.2.0.
The old agent directory and a settings backup were retained. A real prompt,
without a model/provider flag, returned `pi-tate-ready`.

After the final switch, an explicit Syncthing restart retained Tate's declared
device ID and settings. Its live API matched all six fixed peers, the pi
folder, the allow-list and the network options. Both system units reached
active. Restart logs contained no discovery, relay or QUIC startup.

The focused checks passed. Two local Syncthing 2.1.3 processes and pi's pinned
Bun 1.4.2 tested the real settings writer and sync in both directions. The
startup closure check failed on the original missing-script defect and
passed after retaining the Nix path context. Enrollment reruns left IDs and
ciphertext unchanged. Existing Rakku secret values were unchanged. No
plaintext inference API keys were found in tracked files.

`nix flake check --no-build --keep-going` passed for x86_64 evaluation during
the rollout. The full test suite and VMs were not run. ARM was not built.
At the end of that first stage, live sync between fleet hosts was not yet
verified because only Tate was switched. Rakku was not switched.

## Unzen activation, 2026-10-15

Unzen runs source `ce7ffecb38d95ad4731632640cfa1043827d30cd` through
`nixos-rebuild test`. Its runtime closure is
`/nix/store/vnap0ziix7bhhbidk8lkl55mszksfis1-nixos-system-unzen-26.11.20260923.4975466`.
The boot profile remains
`/nix/store/y04lccqhyqhb8bpivnz49wvr17gkr70x-nixos-system-unzen-26.11.20260923.4975466`.
The boot partition still reports FAT I/O errors. No boot write or reboot was
performed. This runtime activation does not survive a reboot. Settings,
Syncthing identities and the app profile remain on persistent storage.
After repairing `/boot`, persist this exact build as root on Unzen with
`nixos-rebuild switch --no-reexec --store-path /nix/store/vnap0ziix7bhhbidk8lkl55mszksfis1-nixos-system-unzen-26.11.20260923.4975466`.

Unzen received settings from Tate without a second seed. Two-way file sync
passed using pi's shipped FileSettingsStorage and a temporary probe field.
The probe was removed, and both final settings files matched. End-to-end
measurements, including SSH probes, were 2.23 seconds from Unzen to Tate and
2.42 seconds from Tate to Unzen. A real pi 1.2.0 prompt used the saved default
and returned `pi-unzen-ready`. The Syncthing identity, fixed peers and network
policy survived a restart. Both units reached active. The host reports
`running` with zero failed units.

A signed deploy-rs app activation on Unzen succeeded through app-deploy,
with `--checksigs`, automatic rollback and magic rollback. Its updater source
checkout at `/var/lib/app-updater/repository` is clean and pinned to the
source above. The updater timer is active, but `/var/lib/app-updater/enabled`
is absent, so it performs no fleet updates. The first ARM build and the
remaining host hooks still need completion before opening that gate.

The updater's builder SSH pins had the same missing Nix path-context issue
as the earlier Syncthing helper. `checks.app-updater-closure` reproduced the
missing file in a sandbox and passed after the fix. CLIProxyAPI's updater
and the decision gateway modules were not changed. No full-suite or VM tests
ran for this activation. Myoko's SSH check and Hiyori's offline state remain
rollout limits.

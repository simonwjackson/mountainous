# Service apps

Mountainous owns accounts, units, storage, secrets and tailnet identity. The
signed app profile owns executables. Logbook and CLIProxyAPI retain their own
deploy paths. The completed groceries pilot is recorded in
[`service-apps-evidence/README.md`](service-apps-evidence/README.md).

## Declare an app

Add a Git flake input exposing `packages.<system>.default` with a `version`.
Declare its destination:

```nix
mountainous.serviceApps.example = {
  input = "example";
  port = 4383;
  schedule = "*-*-* 04:30:00 UTC";
  secrets.example-token = ".config/example/token";
  smokeCommand = "${pkgs.curl}/bin/curl -fsS --max-time 3 http://127.0.0.1:4383/healthz >/dev/null";
};
```

Defaults: account/group `<name>`, 0700 `/var/lib/<name>`, data in `data`, tsnet
state in `state/tsnet`, binaries `<name>-server` and `<name>-tsnet`, profile
`/nix/var/nix/profiles/apps/<name>`. Override CLI arguments, environment and
binary names for other upstream contracts. The backend binds loopback only.
Both units are gated on their profile binary. Only tsnet state is writable by
the sidecar. Impermanence persistence is automatic; Rakku uses
`/tundra/permafrost`.

`secrets` maps host SOPS keys to home-relative regular 0600 files copied from
0400 SOPS files before startup. Mutable OAuth state belongs in persistent data,
not fixed secrets. `readOnlyBinds` adapts legacy credential paths in the unit's
mount namespace. Do not embed credentials in arguments, health contracts or the
store. `checkCommand` is secret/network-free and gets `APP_PACKAGE` in the build
sandbox. `smokeCommand` runs as `app-deploy`, not root. Use bounded checks and
absolute binary paths. Input and schedule must agree across destination hosts.

The host declarations derive app packages, checks, deploy profiles and Unzen's
updater entries. There is no separate app/host registry.

## Deploy and rollback

The updater requires a clean pinned checkout, follows the app's input, pins its
selected revision, rejects downgrades, and builds only the selected app/check
attributes. Native builds use two jobs and empty builders. ARM updater builds
still fail closed until an approved native execution transport exists. A remote
`--store` does not constrain the remote daemon's builders.

Activation resolves the platform's installed immutable controller and uses only
its two permitted sudo commands, `start` and `stop`. The controller controls only
that app's two units. Readiness requires **each unit separately** to be active,
plus the app smoke contract, then five one-second stability samples. Five seconds
exceeds the units' three-second `RestartSec`. Every sample must remain exactly
`active`, with unchanged `MainPID`, `InvocationID` and `NRestarts` for both units.
`activating`, `failed`, and transient restart-loop active windows are rejected. A timeout or
failure rejects activation. Deploy-rs restores the previous executable profile
and runs its activation. Data is not rolled back. Each actual activation briefly
interrupts requests; incompatible data schemas require a separate backup plan.

A first install has no previous accepted profile. On migration failure, stop and
confirm both destination units, quarantine the unaccepted canonical profile link
without deleting generations, and only then resume the previously active source
units. Never start two copies of a tsnet identity.

Service apps have separate `enabled-<name>` gates. Open one only after signed
healthy deployment and rollback proofs. Pi's global `enabled` gate remains closed.
The approved pi check in this stage was x86-only, not deployment/convergence proof.

## Install reusable tools from the repository

Build `.#packages.SYSTEM.service-app-tools` on a native builder with
`--max-jobs 2 --option builders ''`. Copy the closure to execution hosts with
`NIX_SSHOPTS='-F /dev/null' nix copy --no-check-sigs --to ssh-ng://root@HOST STORE`.
Invoke `STORE/bin/service-apps-*`; do not leave loose helper copies on a host.
Every helper has `--help`. Required inputs replace all pilot host/app/branch
constants:

| Tool | Contract |
|---|---|
| `service-apps-check-source-target` | `--runner-host --repo --expected-sha --system`, optional `--bundle --attribute` |
| `service-apps-build-system-target` | `--runner-host --repo --expected-sha --system --host` |
| `service-apps-stage-source-target` | `--runner-host --repo --bundle --branch --expected-sha`; locks against active updater jobs and preserves the previous ref |
| `service-apps-host-target` | `health/compare/switch --host`, repeated `--health-unit`; compare/switch also need `--old --new`; switch requires the exact `--reviewed-diff-sha256` printed by compare |
| `service-apps-run-update-target` | `--runner-host --app --expected-sha --system`; check-only by default; deployment requires explicit `--deploy` |
| `service-apps-rollback-probe` | `--runner-host --repo --expected-sha --state --host --app --system --fixture --health-url --health-equals --output`; optional stable public `--health-identity-key` |

The host comparison covers closure changes and all `/etc` file contents,
including unit files. Inspect it for feature losses before switching. Recheck
current-system identity; do not override a concurrent switch. On Rakku supply
all seven household core units as repeated health arguments.

**Never run rollback probes against a production app.** The probe refuses apps
unless their host declaration explicitly sets `rollbackCanary = true`. Rakku's
`service-app-canary` has its own account, units, private empty state, and two
loopback HTTP ports (4398/4399). It never registers a tailnet name and holds no
credentials or household data. Both failing fixtures target this canary only.

Rollback fixtures expose the healthy app as their `application` input. The probe
pins that nested input to the real app's locked revision, signs the broken
activation, uses deployment graph SSH options/port, and requires runtime rejection,
deploy-rs rollback, the original profile, **all units**, and the supplied public
health contract. It never repairs the destination manually. Backend and sidecar
failures each need their own isolated canary proof. Do not change the groceries
profile while testing. A production sidecar proof on 2026-11-07 caused an outage;
see `service-apps-evidence/review1-incident.md` for the timeline and root cause. Myoko now uses the default OpenSSH port 22;
Tailscale SSH is off. Hiyori remains excluded while offline/unpinned.

## One guarded cutover command

Provision and review the destination system first, with its app profile absent.
Inventory source units/drop-ins, absolute data/config/tsnet directories, ownership,
CLI flags, private-file requirements and exact tailnet identity. Import app secrets
through the established SOPS workflow without logging their values. Keep the
central app update gate closed during migration.

Prepare a private JSON plan (all paths/argv are metadata, never secret values):

```json
{
  "app": "example",
  "source_host": "source-host",
  "source_scope": "user",
  "source_units": ["example.service", "example-proxy.service"],
  "destination_host": "destination-host",
  "destination_user": "example",
  "persistent_home": "/tundra/permafrost/var/lib/example",
  "ssh_options": ["-o", "UserKnownHostsFile=/absolute/pinned-known-hosts"],
  "target_tools": "/nix/store/REVIEWED-service-app-tools",
  "state_paths": [
    {"source": "/absolute/source/data", "relative": "data"},
    {"source": "/absolute/source/config", "relative": ".config/example"},
    {"source": "/absolute/source/tsnet", "relative": "state/tsnet"}
  ],
  "health": {"url": "https://example.TAILNET/healthz", "equals": {"status": "ok", "phase": "ready"}},
  "deploy_command": ["/absolute/reviewed-deploy-command", "public-argument"],
  "verify_command": ["/absolute/app-specific-read-only-integration-test"]
}
```

Run `STORE/bin/service-apps-cutover source --plan PLAN` on the source host.
It refuses before any outage unless **every source unit is active**, both
destination units are stopped, the destination profile is absent, and the
persistence bind and old public health contract pass. Source/state path mappings
must be non-overlapping regular directories without symlinks. Platform-provisioned
destination directories may be empty; existing state is never overwritten.

The tool snapshots active source units, stops and confirms them, retains a stopped
archive on the destination, copies and verifies private state, then executes the
reviewed deploy and integration commands. On a pre-acceptance failure it stops
**and confirms** the destination and quarantines its unaccepted profile before
restoring **only units originally active**. If confirmation fails, the source stays
stopped. On success it disables source units while retaining exact definition
symlinks. External-store definitions report `linked` (exit 1, not enabled), and
remain inactive. Source data and destination snapshots are retained. A completed
migration cannot be rerun: its source is inactive and its destination profile exists.

No system switch occurs inside cutover. Do not use it for symlink-heavy state or
unreviewed data-schema changes. Source data remains authoritative until acceptance;
preserve destination writes for reconciliation if any client writes during backout.
This is an operator-coordinated migration, not a concurrent failover controller.

Groceries-specific credential/persona probes live under `tests/integration/groceries/`.
The pilot-only cutover, staging, preflight, secret-import, source-auth and restoration
scripts were retired after completion; their commands/results remain in evidence.
Zao's original groceries definition symlinks remain linked, inactive and not enabled.
Do not start them while Rakku serves the node.

Groceries' private source remains Zao's repository at
`/home/simonwjackson/code/sandbox/groceries`, main. The existing updater key has
read-only forced `git-upload-pack` authorization for that repository. Zao is an
update-source availability dependency, not a runtime dependency. Rotate both
`groceries-assistant-service-token` and clients' `pi-assistant-groceries-token`
SOPS entries together.

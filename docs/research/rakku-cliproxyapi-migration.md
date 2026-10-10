# Rakku CLIProxyAPI migration and application-only updates

## Accepted deployment

CLIProxyAPI now runs on Rakku. Unzen builds and deploys the application. Zao no
longer runs its core, sidecar, or quota router. The operator approved the
migration and automatic adoption of stable upstream releases that pass checks.
Both tested host configurations are now their default system generations. No
reboot was requested during cutover or permanent acceptance.

The earlier proposal recorded CLIProxyAPI 8.0.7. Fresh inspection before cutover
found 8.0.23. The migration preserved that running release and its companion
binaries. It did not combine the move with an upstream upgrade.

| Component | Accepted deployment |
| --- | --- |
| Runtime | Rakku system account `cliproxyapi`, home `/var/lib/cliproxyapi`. |
| Core | CLIProxyAPI 8.0.23, bound to `127.0.0.1:8317`. |
| Client endpoint | `https://cliproxyapi.hummingbird-lake.ts.net`, same dedicated node at `100.89.52.98`. |
| Accounts and catalog | Seven OAuth accounts and 47 models at acceptance. |
| Scheduler | Native Antigravity quota plugin registered and enabled. |
| Quota router | Rakku oneshot service and two-minute timer. |
| Application profile | `/nix/var/nix/profiles/per-user/cliproxyapi/application`. |
| Builder and deployer | Unzen, through deploy-rs for `.#rakku.cliproxyapi`. |
| Release selection | `nix-update --flake cli-proxy-api --version stable`. |
| Nightly schedule | 03:00 UTC, with up to 15 minutes of random delay. |
| Application source | `/home/simonwjackson/code/sandbox/cliproxyapi-nix/.worktree/rakku-deploy`, revision `416cbda5ae166e49bbd058e6615bc9f418e51e85`. |

The latest-stable check selected 8.0.23 and passed without deployment. The actual
scheduled service path also ran successfully and recorded `already-current`.
Its enable marker exists, and the timer is active. There is no Forgerie
installation on Rakku.

## Ownership and security

NixOS owns accounts, units, permissions, persistence, and public deployment
keys. The independent application profile owns the core, sidecar, router,
account tools, and scheduler library. Nightly updates do not rebuild Rakku's
NixOS system, Home Assistant, or Z-Wave JS.

The application account has no wheel or Nix trusted-user access. Unzen signs
application closures. deploy-rs requires signature checks and pinned SSH host
identities. The deployment account's only root operation is a fixed helper
with six proxy-only service-control actions.

Unzen generated and holds its private deployment and signing keys under
`/var/lib/cliproxyapi-updater`. Only public keys entered host configuration.
Provider credentials and dedicated Tailscale state did not go to Unzen.

| Preserved state | Path relative to `/var/lib/cliproxyapi` |
| --- | --- |
| Provider credentials | `.cli-proxy-api/`. |
| Runtime configuration and management environment | `.config/cliproxyapi/`. |
| Dedicated Tailscale identity | `.config/cliproxyapi-tsnet/`. |
| Quota history and reset ledger | `.local/state/cliproxyapi-quota-router/`. |

Rakku persists this home through Impermanence. The home profile alias points to
the independent application profile. Activation repairs the alias after the
persistent home is mounted, before checking the scheduler library.

## Cutover and verification

The coordinator stopped all source writers before exporting 43 state files.
It tested an encrypted backup restore and verified transferred bytes before
rebasing home paths. It then opened Rakku's startup gate and deployed from
Unzen. Only one copy of the dedicated node identity ran at a time.

The first attempt failed because the target home profile alias was absent.
Recovery stopped Rakku and restored its newest state to Zao before restarting
Zao. The activation fix passed three regression tests. The second cutover
passed acceptance and retired the source.

Acceptance checked authenticated loopback and tailnet catalogs, account
identities and enablement, client keys, protected configuration, the reset
ledger, scheduler registration, fresh quota observations, and blocked
management routes. It used zero paid inference requests and zero reset
requests. The sidecar's static `/healthz` alone was not an acceptance gate.

Zao's four application units are inactive and masked. Its active credential,
config, node-state, and quota directories are removed. Plaintext transfer
archives are removed on both hosts. Encrypted recovery backups remain.

Rakku's fresh Home Assistant comparison passed after cutover and again before
final completion. It preserved 57 devices, 633 registered entity identities,
radio identities, loaded integrations, and baseline availability. HA and
Z-Wave process IDs and invocation IDs did not change during host acceptance.
Existing integration retries and unavailable battery entities were not fixed
by this migration. Do not issue a software reboot to test Rakku's unresolved
restart failure.

## Evidence and operations

Private evidence is outside Git:

- Zao: `~/.local/share/mountainous/migrations/cliproxyapi-rakku/`, including
  `cutover-status.json`, `cutover-events.jsonl`, and the encrypted backup.
- Rakku: `/nix/var/cliproxyapi-migration/`, including HA before/after inventories
  and `rakku-host-accepted.json`.
- Unzen: `/nix/var/cliproxyapi-migration/unzen-host-accepted.json` and
  `/var/lib/cliproxyapi-updater/receipts/`.
- Application account: `.accepted-profile.json`, `.migration-accepted.json`,
  and `.accepted-runtime.json` under its home.

The final cutover phase is `migration-complete-source-retired`. Both hosts'
`/nix/var/nix/profiles/system` links match their accepted running configurations.
The booted configurations remain the previous generations because no reboot
occurred. `scripts/cliproxyapi-host-stage` retains the tested acceptance helper.
The other `scripts/cliproxyapi-*` files retain the transport and recovery steps.

For application operations, use `docs/rakku-deployment.md` in the application
repository. The timer and manual updater share a deployment lock. Do not run
the copied source identity or restore old credentials while Rakku is running.

## Costs and limits

Application restarts can interrupt active model streams. deploy-rs rolls back
executable profiles, not mutable credential or state schemas. Each activation
creates an encrypted state backup, but incompatible schema recovery still
needs an operator. Checks cannot prove every future provider API or token
refresh behavior. Expired or revoked credentials can still require login.
Failed updates leave private receipts and a failed systemd unit. There is no
external push-alert integration.

Primary deployment references are the
[deploy-rs README](https://github.com/serokell/deploy-rs/blob/master/README.md)
and the
[NixOS automatic upgrade module](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/tasks/auto-upgrade.nix).
Whole-system automatic upgrades were rejected because they can change Home
Assistant. The accepted design updates only the application profile.

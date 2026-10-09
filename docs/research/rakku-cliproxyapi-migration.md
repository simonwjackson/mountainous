# Rakku CLIProxyAPI migration and application-only updates

## Status

This is a proposal, not an approved architecture or a completed migration.
No service, credential, Tailscale identity, or update policy has changed.
The source host is verified as Zao. The operator called it "Xeo" in the request.
Both named services exist on Zao as active systemd user services.

## Verified current deployment

| Component | Current deployment |
| --- | --- |
| CLIProxyAPI | Version 8.0.7, running from the operator's Nix profile. |
| Tailscale sidecar | Custom Go package `cliproxyapi-tsnet-1.0.0`, active as a user service. |
| Quota routing | Separate oneshot service and active timer with `OnUnitActiveSec=2min`. |
| Packaging | Local repository `/home/simonwjackson/code/sandbox/cliproxyapi-nix`; no configured Git remote. |
| Upstream release selection | Explicit version 8.0.7 and release archive SHA-256 in `flake.nix`. |
| Bundle | Includes upstream binary, sidecar, Python router and account tools, and native Antigravity scheduler plugin. |
| Automatic application upgrade | No CLIProxyAPI nightly update timer found in the user manager. |

Sources inspected directly:

- Installed user units for `cliproxyapi.service`, `cliproxyapi-tsnet.service`,
  `cliproxyapi-quota-router.service`, and `cliproxyapi-quota-router.timer`.
- `systemctl --user show`, `/proc/<MainPID>/exe`, and profile executable links.
- The application repository's `flake.nix`, `README.md`, `proxy/main.go`,
  `docs/tailscale.md`, and `docs/quota-router.md`.

The installed profile contains a newer derivation of CLIProxyAPI 8.0.7 than the
running core process. The sidecar executable has its own store path. Version
strings alone do not establish which build is running. Cutover must preserve
and test actual executable closures, not only package labels.

## State that must move

| State | Current path under `/home/simonwjackson` |
| --- | --- |
| Provider credential files | `.cli-proxy-api/`. |
| Runtime config and management environment | `.config/cliproxyapi/`. |
| Dedicated Tailscale node identity | `.config/cliproxyapi-tsnet/`. |
| Quota observations and reset request ledger | `.local/state/cliproxyapi-quota-router/`. |

Keep secrets out of Nix store derivations and Git. Preserve file permissions.
Stop all state writers during the final copy. Only one sidecar may run with the
copied Tailscale identity. Only one quota router may poll or redeem resets for
the migrated installation. Preserve the durable reset ledger; losing it can
allow a retry to spend another reset.

The quota timer and scheduler plugin are required for the current routing and
quota behavior. Moving only the two named services is incomplete.
No Forgerie installation on Rakku is needed.

## Recommended ownership split

NixOS declares the service users, units, persistent state, secret references,
loopback bind, and update policy. A dedicated Nix application profile owns the
proxy bundle's executable generation. Service executables reference that profile,
not the operator's general-purpose profile and not a package interpolated from
the NixOS system closure.

A nightly systemd job on Zao can build and deploy application generations to
Rakku. Keep the application package's nixpkgs input separate from Rakku's pinned
Home Assistant runtime. Do not run a nightly NixOS rebuild or reboot Rakku.
Build resources on Zao avoid competing with Home Assistant on Rakku's J1900.

Proposed update steps:

1. Select a stable upstream release or an operator-approved application commit,
   according to the policy the operator chooses.
2. Record the exact source, version, archive digest, and package revision.
   Updating only `flake.lock` does not update the currently hard-coded release.
3. Build the bundle and run its checks. Add real compatibility checks for the
   native scheduler plugin against the selected upstream binary.
4. Copy the complete closure, retain the previous profile generation, and
   activate the dedicated application profile.
5. Restart only affected application units. Verify upstream API routing, fresh
   quota observations, plugin registration, and blocked management routes.
6. Restore the previous application generation and restart affected units if
   acceptance fails. Retain evidence and notify the operator.

Do not redeem a banked reset in deployment tests. Any paid model inference test
must have an agreed cost limit. In-flight model streams can fail during a core
restart. Binary rollback does not automatically reverse credential or state
schema changes. An update with incompatible state changes must require operator
approval and an explicit recovery plan.

The sidecar's `/healthz` returns its own static status. It does not probe the
upstream core. An HTTP 200 from that endpoint is not application acceptance.

## NixOS and deploy-rs options

| Option | Benefit | Cost or limitation |
| --- | --- | --- |
| Dedicated application profile with direct Nix commands | Updates only this application and follows Mountainous's direct-command policy. | We must implement release selection, restart ordering, application checks, and rollback. |
| Dedicated application profile through deploy-rs | Supports custom activation and independent non-system profiles. | Adds a deployment dependency. A timer or CI scheduler and release-selection job are still required. SSH confirmation is not proof that model routing works. |
| `system.autoUpgrade` | Provides a built-in daily system update timer. | Activates a whole NixOS generation and can affect Home Assistant. It does not fit application-only updates. |

Primary external sources:

- [deploy-rs README](https://github.com/serokell/deploy-rs/blob/master/README.md),
  especially Multi-profile, Profile, custom activation, and rollback options.
- [NixOS automatic upgrade module](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/tasks/auto-upgrade.nix),
  especially `system.autoUpgrade.enable`, `dates`, `allowReboot`, and the
  generated `nixos-rebuild` invocation.

## Decision required

Choose whether nightly updates automatically adopt stable upstream releases
that pass checks, or only deploy explicitly approved application revisions.
Automated checks reduce risk but cannot prove every provider's private API or
future credential migration is compatible.

After that decision, implement the Cairn service layer and app-only deployment.
Before and after cutover, repeat Rakku's existing HA availability gate. Preserve
all 187 baseline-available entities, radio identities, and host persistence.
Do not issue a software reboot; Rakku's restart failure remains unresolved.

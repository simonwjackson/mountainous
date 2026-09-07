# Federation maintenance isolation: bounded VM-verified slice

This is **not a live cutover runbook**. The consumers are disposable VM fixtures and the test-only combined supervisor. Independent review is still required. No host module enables these operations.

`scripts/federation_isolation.py` owns unit isolation only. It does not write identity, trust, the bundle selector, network rules, generation profiles, or recovery state. The approved ownership replacement and retirement of all old pairings are separate work. This slice does not reopen that approval.

## Contract

| Operation | Behavior |
| --- | --- |
| `Isolation` context | Requires root and the declared UID 1000 home. Holds the existing `/run/lock/korri-device-gate.lock` used by producer `services/inputd/deploy/device-check.sh`. A private manifest lock also excludes competing artifact writers. |
| `emergency_stop()` | Stops/drains the fixed authorities and user activation without reading, saving, deleting or adopting artifact evidence. It stops the root worker only after matching the process-local invocation/cgroup receipt and transient root unit contract. It attempts the remaining authorities when one proof fails, then returns refusal if any stop/drain proof is uncertain. This proves neither masks nor reboot closure. |
| `close()` | Calls `emergency_stop()` first, so artifact failures cannot suppress stopping. Then creates every persistent gate before runtime masks, verifies masks, cancels explicit affected job IDs, and stops the authority units **and user `nixos-activation.service`** again. Proves inactivity, empty cgroups, and no affected jobs. Only then retires exact owned worker evidence so another invocation can be recorded. It refuses game-unit evidence rather than deleting it. |
| `own_activation_worker(invocation_id)` | Records public evidence for the separately created `korri-maintenance-activation.service`. Requires the supplied invocation ID, a root transient unit, its exact cgroup, and `KillMode=control-group`. Captures a separate process-local stop receipt before the fallible manifest save. Valid protected worker evidence can still be opened by the isolated gate consumer; changed evidence is not adopted. Call `close()` to finish and retire the previous worker **before starting its replacement**. Different or unrecorded invocations are refusals, not processes to kill by name. |
| `remove_masks()` | Requires stopped authorities and user activation, a finished root activation worker, no relevant queued jobs or saved activation-list requests, and no failed or unknown permit evidence. Removes only recorded masks; persistent per-unit conditions remain. |
| `permit("sunshine.service")` | Requires all masks to be effective while creating and persisting one root-owned, nonpersistent permit. The order is `close()`, `permit()`, then `remove_masks()` **only after success**, then start Sunshine. No launch, importer, inputd, or legacy-user permit operation is exposed. This does **not** provide the full dependency set or network isolation needed for actual Sunshine maintenance. |
| `restore()` | Checks every owned artifact before deletion, closes units again, and removes only exact recorded artifacts. Does not restore previous active state or restart units. This release operation is only wired in the VM; its future caller must separately prove accepted boot state and the trust boundary. |

`Manager(user)` uses one authenticated local user-bus transport. Before every
command it validates the declared UID 1000/GID 100 account, its `/home/<user>`
ancestry, and the nofollow `/run/user/1000/bus` ancestry. The runtime directory must
be `1000:100`, `0700`; the socket must be `1000:100`, `0666`, single-link. Root
ancestors must retain `root:root`, `0755`. It then executes immutable Nix-store
`systemctl --user` as UID 1000/GID 100 with **no supplementary groups**, fixed
`XDG_RUNTIME_DIR=/run/user/1000` and
`DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`. Fixed
`SYSTEMCTL_FORCE_BUS=1` is essential: systemd 259 otherwise prefers its private
manager socket despite the session-bus address. Its environment does not inherit
caller-selected bus addresses. The parent and system-manager commands
remain root, including gate and manifest writes. No sudo helper, machine bridge,
transport fallback, or user-writable executable is used. Unknown accounts, unsafe
ancestry/socket metadata and failed queries refuse; they never mean empty jobs,
absent units or drained authority. This does not change the existing loaded-unit,
legacy-authority, job or cgroup proofs.

The fixed authority set is 10 system units and four UID 1000 user units. It includes both system sockets, the legacy user socket, identity importer, selector, bundle consumers, compositor, and legacy `x11-headless.service`. It deliberately excludes SSH, management, the user manager, and `korri-input-source-guard.service`.

## Filesystem and precedence

| Artifact | Location |
| --- | --- |
| Persistent system drop-ins | `/etc/systemd/system.control/<unit>.d/90-korri-maintenance-isolation.conf` |
| Persistent legacy-user drop-ins | `<home>/.config/systemd/user.control/<unit>.d/90-korri-maintenance-isolation.conf` |
| System runtime masks | `/run/systemd/system.control/<unit> -> /dev/null` |
| Legacy-user runtime masks | `/run/user/1000/systemd/user.control/<unit> -> /dev/null` |
| Per-unit permits | `/run/korri-maintenance-isolation/{system,user}-<unit>` |
| Operational evidence | `/var/lib/korri-maintenance-isolation/manifest.json` and optional `activation-worker.json` in a root-owned 0700 directory. |

The drop-in has one non-triggering `ConditionPathExists=` per unit. A condition on a dependency is not enough. No boot or tmpfiles operation creates permits. A crash removes permits and runtime masks but leaves persistent conditions. The `.control` drop-in paths avoid writing through NixOS's normal store-linked `.d` directories.

The manifest contains public path, inode/device, ownership/mode, file digest or symlink target, and boot-ID evidence. The live writer separately retains the manifest's exact bytes and nofollow metadata receipt, including inode, ownership, mode and link count. It checks that receipt before every save and removal. It updates the receipt only after its own inode replacement and directory sync. Missing, replaced or changed durable evidence latches refusal; no in-memory reconstruction or overwrite is allowed. It is operational evidence, not a Korri product schema. Creations are exclusive; regular files and directories are synced. No existing unit or mask is overwritten. Changed artifacts or unexpected directory contents refuse cleanup before the first removal. Missing runtime artifacts are accepted only across a changed boot ID. An interrupted creation before manifest sync is an **unowned collision**, never permission to delete it. No error handler removes isolation. A failed manifest save blocks further verification/release in that writer. An unfinished `manifest.next` or an unrecorded permit also blocks release after reopening. `close()` can refuse artifact work on such evidence, but first attempts bounded emergency stopping. Do not infer effective masks from that stop alone. The combined caller records stopped/closed/unknown status separately. Do not delete the permit or persistent gates to force a retry. A reboot expires `/run` permits but retains all persistent conditions. Malformed manifests raise `Refusal`, release both locks, and remain unchanged for inspection.

Existing Sunshine user masks remain at their original inode and target. Runtime masks are not restored by guessing prior link text. Only the exact links created by this attempt are removed.

## Verification

Run the local-only check from the worktree:

```console
./tests/run-federation-isolation.py
```

This resolves the root `nixpkgs` input from `flake.lock` without changing the lock, runs filesystem tests, and builds/runs `tests/federation-isolation.nix`. It does not need new files staged because it evaluates the standalone Nix file directly. It needs KVM, about 2 GiB of guest RAM, Nix build inputs, and several minutes. Use `--unit-only` for the filesystem/parser tests, not as a substitute for VM acceptance.

The VM asserts systemd **259** and the exact materialized activation executable:

`/nix/store/i1d0j73p75qykj8m0bfvi6wk829p0g9p-switch-to-configuration-0.1.0/bin/switch-to-configuration`

It calls each fixture generation's own `bin/switch-to-configuration`; it does not compile a guessed source copy. The old, candidate, and recovery fixtures use actual NixOS generation activation and GRUB boot selection. They have real service processes and sockets, not Korri binaries or production identities.

Coverage includes 13 filesystem/parser tests and 13 real VM subtests. The additional filesystem test exercises byte, inode, missing-file, mode and hardlink drift against both save and removal. The VM checks ordinary runtime masks losing to managed `/etc` units; effective high-precedence masks; collision refusal; and system and legacy-user queued jobs. The actual UID 1000 caller requests its root supervisor through one fixture-only, argument-free sudo command, then is killed while that supervisor works. No root test-driver launch substitutes for that request.

The VM also checks hung root activation; hung user `nixos-activation.service` and its child outside the root worker cgroup; two distinct real root-worker retry invocations (failure, then success); exact evidence retirement and refusal on a read-only evidence filesystem; a permit manifest-write `EROFS` failure with masks retained in the same process and after reopening; unchanged SSH/management/user-manager PIDs and an SSH connection across activation; individual service/socket gates; power loss while Sunshine has a permit; old/candidate/recovery boots; and exact artifact restoration.

Two pinned-tool details matter:

- A saved `korrid.service` request in `/run/nixos/start-list` makes the first real retry return **4** because the unit is masked. The tool itself consumes the list. A subsequent retry succeeds under the same masks. The gate never clears the list or treats status 4 as success.
- The minimal fixture exposed an unresolved `pam_syslog` symbol in pinned `pam_lastlog2.so`. The VM disables only login/SSH WTMP history recording. PAM authentication remains enabled. Maintenance operations now use the actual-user bus path, not the machine bridge. This is a fixture workaround, not a production PAM fix.

The transport regression executes an immutable credential-checking wrapper which
then execs the real systemd 259 `systemctl`. It checks all real/effective/saved IDs,
empty groups and the explicit bus environment. All gate/drain/reboot tests use
that wrapper; closed-gate assertions also require root ownership. Additional real
filesystem/process cases reject unknown accounts, a mutable executable, symlink
or nonprivate runtime ancestry, missing/symlink/non-socket/wrong-owner/wrong-mode/
hardlinked bus paths and a correctly owned socket whose connection fails.

## Limits before parent integration

A successful initial `close()` is the boundary before any mismatch or private-state mutation. An interruption while initially staging 14 gates cannot atomically gate all 14 units. Stop before cutover if staging fails; inspect the retained partial artifacts. Once the full gate set is installed, subsequent failures retain it.

The stricter transport costs refusal on account, home or bus metadata drift; it does not repair that drift. Bus checks are observations, not a lock against replacement by UID 1000. The lock coordinates cooperating operators. It cannot exclude an unrelated root deployment process or hostile UID 1000 changing its writable home ancestors. The immediate artifact directories are root-owned, but the user can replace its own `.config` ancestors. Future preflight must exclude such writers and inspect every old/candidate/recovery generation for conflicting gate paths or condition resets. Do not claim a sandbox boundary against the same user whose manager is being controlled.

`restore()` is a reviewed release boundary, not an exception handler. Do not call it after an ambiguous identity/trust write or while the unaccepted old-owner boot default remains selected. The module does not prove successful activation history, ownership, trust retirement, boot acceptance, or selector agreement. A failed deletion/fsync during release needs inspection; there is no transaction that restores all gates automatically. The combined consumer therefore keeps persistent conditions through final runtime verification and the durable release-evidence save. Exact guard cleanup occurs only after that success boundary. A cleanup failure after that boundary must not be described as reboot-closed. See the combined supervisor runbook for that caller-owned ordering.

There is no network filter in this module. No live Zao preflight, private-state access, device test or deployment was performed. The separate combined consumer supplies the inspected Sunshine dependency permits and network receipt only in its test/implementation scope. Existing game cgroups outside the declared authority units, new activators, concurrent deployments, and producer API acceptance remain parent integration concerns. The cost of these gates is an explicit maintenance outage and fail-closed manual recovery after reboot, not unattended rollback.

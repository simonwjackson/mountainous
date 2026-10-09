# Rakku: in-place Cairn migration

## Scope and preservation contract

Port Rakku from `unified` into Cairn's named layers. Do not install Forgerie,
format disks, rename the existing account, update radio firmware, reset a
controller, re-pair a device, or upgrade Home Assistant/Z-Wave during this change.

The source configuration is `unified:hosts/rakku/`. The live system is the
reference for state paths and runtime versions, not the newer unified branch.

## Verified baseline

Read-only inspection on 2026-10-09 verified SSH at `192.168.1.178` against the
existing RSA key in `secrets/hosts/rakku-rsa.pub`.

| Item | Live value |
| --- | --- |
| Hardware | Intel Celeron J1900, 4 cores, 7.6 GiB usable RAM, 59.6 GiB SSD. |
| System | NixOS 26.05, nixpkgs `1306659b587dc277866c7b69eb97e5f07864d8c4`. |
| Home Assistant | 2025.12.3, `/var/lib/hass`, UID/GID 286. |
| Z-Wave server | 3.4.0, driver 15.15.0. |
| Registry | 57 devices, 633 entities, 37 integration entries. |
| State | RAM-backed root; Btrfs `@nix`, `@log`, `@permafrost`; existing 8 GiB swap. |
| Operator | `simonwjackson`, UID 1000. |
| Controller | HubZ serial `61600558`, Z-Wave interface 00 and Zigbee interface 01. |

Home Assistant's Z-Wave entry points to the old address `ws://192.168.1.181:3000`.
The server on Rakku is reachable at localhost:3000, but the HA integration is in
`setup_retry`. Roborock and five Yeelight entries also have setup retries; the
MCP server entry is not loaded. Preserve registrations and distinguish these
pre-existing failures from migration regressions. Do not silently edit them.

Tailscale is logged out, and `tsnet-proxy-habitat` is retrying. Joining the machine
and repairing the separate Habitat proxy identity are different operations.

## Module layout

- `modules/hosts/rakku.nix` selects the server, home-automation and
  home-network-services layers and declares host-specific hardware/access.
- `modules/home-automation.nix` forwards directly to upstream HA/Z-Wave options.
- `modules/home-network-services.nix` preserves Habitat, Tinyproxy and AirConnect.
- `disks/rakku-existing.nix` retains the exact live fstab partition labels and
  impermanence layout. The deployment gate verifies the backing UUIDs. It deliberately exposes no Disko installation target.
- `secrets/hosts/rakku.yaml` holds the two existing agenix values, re-encrypted
  unchanged with SOPS. Rakku also joins the fleet SOPS recipient list.

The host uses its deployed nixpkgs input. Cairn's current SOPS/Hjem binaries use
their own upstream build toolchains rather than the older host compiler. This
keeps the HA executable and Python dependency paths unchanged. The cost is an
old runtime/security baseline until a separate, backed-up upgrade is approved.

The original RSA SSH key and `simonwjackson` UID 1000 remain. Cairn's `simon`
account is added as UID 1001. The new Ed25519 SOPS key is staged in persistent
storage before activation. `/etc/ssh` links to it; SOPS reads the persistent path
directly because user-secret decryption runs before file-link setup on cold boot.
`stateVersion` remains 24.11.

The DHCP client, NIC MAC, and LAN address stay unchanged. The firewall is enabled
but trusts the existing LAN NIC `enp1s0` and `tailscale0` to preserve discovery and
dynamic event callbacks. Spare NICs are not trusted. Narrowing LAN ports is a
separate change; it was previously entirely unfiltered.

## Backup and rollback

`scripts/rakku-backup-target` stops HA, reads the Z-Wave controller backup API,
stops Z-Wave/Habitat, verifies the databases, snapshots persistent storage,
copies the real Z-Wave cache and boot files, and makes a root-only archive.
It restarts the original services even if backup fails.

The HubZ controller rejects raw NVM backup with **ZW0209: Unknown NVM size**.
The backup records this specific unsupported operation. It does not change the
firmware to obtain a backup. Security keys, controller identity, host cache and
the physical controller remain intact. The backup does not cover replacement
of failed Z-Wave controller hardware. Other controller errors abort the backup.
Zigbee network backups are present in `zigbee.db` and are included in full.

The actual Z-Wave cache is `/var/cache/private/zwave-js`; `/var/lib/zwave-js` is
empty. The port persists `/var/cache/private`, preserving systemd DynamicUser
ownership and symlink handling. The cache is copied with services stopped.

`scripts/rakku-transport fetch-backup` encrypts the SSH stream to the operator's
Ed25519 public key. `scripts/rakku-verify-backup` decrypts into a private tmpfs
directory, restores regular files without following symlinks, checks every file's
bytes and archived ownership/mode, and runs SQLite integrity checks. It never
starts a second HA instance or connects to radios. It removes the plaintext
when the check exits. A verified restore receipt is required for activation.

`scripts/rakku-switch-target test` arms a 15-minute local rollback, stages cache
persistence, and activates the candidate without selecting it for boot. The
rollback saves failed application state, restores the backup and old system,
and restarts the old services. Accept only after external checks pass. Accept
selects a one-shot candidate boot and cancels the timer; the old generation stays
the fallback. After a real reboot passes, `finalize` makes the candidate the
default boot entry. Keep the archive and the old generation after acceptance.

## Acceptance

- `tests/rakku-contract.nix` checks the evaluated host: exact HA/Z-Wave executable
  paths, old storage labels, stateVersion, owners, USB path, cache path, secrets,
  access and absence of a destructive Disko configuration.
- `tests/test_rakku_migration.py` exercises real archive extraction, SQLite
  restoration, corrupt/missing-file refusal, path traversal refusal, and the
  device/connection comparison contract.
- `scripts/rakku-inventory` uses read-only localhost HA APIs and registry files.
  It keeps credentials in memory and never modifies the auth store. It records
  version, device/entity identities, integration loading and availability.
- Compare a fresh pre-cutover baseline, after activation, and after reboot.
  Compare Zigbee coordinator/PAN/key fingerprints and Z-Wave home/node IDs too.
  A healthy HTTP port alone is not acceptance. Test available integrations and
  radio identities without triggering locks, alarms or other physical actions.
- `scripts/rakku-verify-target --booted` requires the actual booted-system path,
  active services, original secret bytes, user IDs, USB interfaces, tailnet name,
  and live state paths backed by persistent mounts.

## Evidence locations

Private connection inventories and encrypted archives belong outside Git under
`~/.local/share/mountainous/migrations/rakku-cairn/`. On Rakku, root-only backup
snapshots and activation receipts live under `/nix/var/rakku-migration/`.
No credential values, authentication tokens, or device backups belong in Git.

## Deployment evidence

The first test activation refused duplicate regular files at `/etc/ssh` where
Impermanence expected links. The guarded rollback restored the old application
state and system. A fresh comparison then verified all 57 devices, 633 entity
registrations, 187 originally available entities and loaded integrations.
The corrected identity staging passed a regression test and the real
Impermanence helper. A separate gate now checks the early-boot SOPS key path.

The corrected candidate passed test activation and the same live connection
checks. The `update.aka_firmware` entity takes several minutes to regain its
state after either old or new runtime starts; the gate waits for it rather than
ignoring or excluding it. No device was re-paired.

The encrypted backup contains 394 verified files. Both restored SQLite databases
pass `PRAGMA integrity_check`. Its SHA256 is
`4e022d78626ea0a674aa31be205f87d2928204f9ebb343323fd8fa9d112a5fbe`.
Its path is `~/.local/share/mountainous/migrations/rakku-cairn/pre-cairn-20261009-v2.tar.gz.age`.
The old system closure has GC roots both on Rakku and on Zao.

Rakku rejoined the tailnet as `rakku.hummingbird-lake.ts.net` at `100.88.212.117`.
Habitat still fails with `invalid key: API key does not exist`. A transient
`active` service status is not proof the proxy serves HTTP; its DNS name does
not resolve. Its original secret was preserved unchanged, not silently replaced.

## Boot recovery and current status

The first one-shot candidate
`/nix/store/875sh489svkxz6lq2hxn96xxp4h92x3g-nixos-system-rakku-26.05.20251215.1306659`
passed live checks but did not return on the LAN or tailnet after reboot. A fresh
port-22 scan of all 253 other LAN addresses found no host matching Rakku's key.
The default boot entry was set to the original system before the one-shot trial.
Finalize had not run at that point. The operator was asked to power-cycle once;
neither radio was reset.

Inspection of both actual initrds showed that the candidate omitted `usb_storage`,
which the original hardware module included. This omission is fixed, and a new
regression assertion fails without it. It is not yet proven to be the cause of
the failed boot. The corrected system is built locally at
`/nix/store/73i4bcrdxm225yvcvxv6kkdm1sj3g9lx-nixos-system-rakku-26.05.20251215.1306659`
and linked from `/tmp/rakku-cairn-recovery-system`.
Sixteen Python tests, the Nix host contract, Ruff and formatting pass.

The operator power-cycled Rakku. It returned at `192.168.1.178` and had actually
booted the Cairn `875sh...` candidate. All 57 device IDs, 633 entity registrations,
187 previously available entities, loaded integrations, radio identities, SOPS
secret bytes and persistence checks passed after the physical boot. `lsblk`
verified that the SSD uses SATA. The omitted USB-storage driver is therefore
not evidence of a missing driver for the root disk. The previous boot journal
ends during filesystem unmounting; the cause of the failed software restart is
not proven. This working Cairn generation was finalized as the default.

The boot-driver-only `73i4...` follow-up has identical `etc`, `sw`, kernel and
kernel-module paths. It was copied to Rakku, activated, and passed the full
connection inventory without restarting HA. Its first two staging attempts
reported the known Habitat authentication failure and reverted only the system
selection, without restoring or changing HA state. The subsequent attempt passed.
Generation 42 was prepared as a one-shot boot, retaining the verified Cairn
generation 41 as default/fallback.

**Final image cold-boot verification is still incomplete.** A second software
reboot again left Rakku unreachable. Another complete LAN SSH scan found neither
its SSH identity nor its known NIC MAC, and the tailnet ping timed out. The
external watcher was stopped. The operator has been asked to power-cycle once
more. Do not issue further software reboots during this migration.

After recovery, verify `/run/booted-system`, then run inventory and host checks
against `73i4...`. If they pass, finalize that image and collect the private
receipts. Leave the machine running. Investigating unreliable software restart
is a separate follow-up, not a reason to reset devices or radio controllers.

Temporary orchestration on Zao is in `/tmp/rakku-final-prepare.sh` and
`/tmp/rakku-acceptance-watch.py`. The latter accepts `--candidate` and `--booted`;
do not use its old default candidate. Durable migration tools are in `scripts/`.
On Rakku, the backup root holds `inventory.py`, `verify-target.py`,
`switch-target.py`, `pre-cutover.json`, `post-test.json`, `host-post-test.json`,
`boot-trial.json`, and the tested backup/rollback evidence. `/tmp` files on Rakku
are not guaranteed to survive reboot.

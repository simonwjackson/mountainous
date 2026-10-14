# Fuji on permafrost: port and reinstall plan

## Status and scope

Fuji's migration is complete. It runs cairn as a builder on btrfs with a tmpfs root. The reinstall on 2026-10-14 preserved SSH identity, but the next reboot exposed a join-service race that deleted the original Tailscale registration. The repaired service passed two subsequent reboots with the new registration unchanged and the original IPv4 restored. Retained data and real distributed builds passed verification.

Fuji is the fleet's aarch64 builder. This plan moves it from `unified` (agenix, XFS, mutable root) to this branch (sops, the permafrost layer from `docs/plans/yari-forgerie-host.md`). The disk layout, Tailscale carry-over and install tool are the same as Yari's.

On 2026-10-13 the operator chose which services Fuji keeps: only the builder. These old services are not ported and stop at the install:

- Syncthing and its 9 folders. The folder contents are in the keep set. The device cert and key stay in `secrets/hosts/fuji.yaml`, so the device ID can come back.
- `omi`, `biometrics-sync` (Oura, Withings, Keto-Mojo), `kroger`, `vpn-ns`, `fail2ban`, `nix-optimise`.
- Borg and its cloud sync. Copies stay in Dropbox and Google Drive; backups get set up again later.
- `tsnsrv`, PostgreSQL and Podman. None of them ran.
- x86_64 emulation, Sobo's builder key, and the old command-line tools.
- The hand-started processes: Sunshine, Xvfb, RetroArch, 2s2h, dropbear on port 2224, and the input watcher.

## Facts this plan depends on

Read on Fuji, Yari or Zao on 2026-10-13.

| Fact | Value | Source |
| --- | --- | --- |
| Machine | Oracle Ampere A1 VM, 4 cores, 23 GiB RAM, 200 GB boot volume, up 155 days | `nproc`, `free`, `lsblk` on Fuji |
| Boot volume | `/dev/disk/by-id/scsi-360dcd7caf93c46798175207d39b51cf7` | `/dev/disk/by-id` on Fuji |
| Builder load | 578 build connections to nix-daemon in 7 days | `journalctl -u nix-daemon` on Fuji |
| Build directory | The nix-daemon builds in `/nix/var/nix/builds` when `build-dir` is unset | `nix config show`, directory present on Yari |
| Links | Fuji -> Yari 147 MiB/s. Yari -> Zao 4.67 MiB/s. Fuji -> Zao 0.06 MiB/s on one stream, 0.55 MiB/s on eight | `ssh` with random data |
| Real data | About 1.1 GB after removing what Zao, a remote, or a tool already holds | Repo-by-repo comparison against Zao |

## Decisions

### Same layers as Yari

Fuji uses `layers = [ "server" "permafrost" "oracle-vm" "builder" ]`, as Yari does. Its host file adds only the boot volume and the signing key. Builds run in `/nix/var/nix/builds`, which is on the `@nix` subvolume, so the 4G tmpfs root does not limit build size. The `fuji-host` check fails if `build-dir` is ever set.

### User `simon`, not `simonwjackson`

This branch has one user, `simon`, at `/home/simon` (`modules/users.nix`). Fuji follows Yari. Cost: every reference to `simonwjackson@fuji` breaks, including Zao's builder entry (see below).

### Secrets in sops, identities kept

`secrets/hosts/fuji.yaml` preserves the legacy `fuji-1` Nix signing key. Its public key is `fuji-1:0mnvKZa4ZzMJgSgFfQLdQzwcdUtiGqZxxcImE/i9wDo=`. It also keeps the Syncthing cert and key, unused for now. Fuji's SSH host key is unchanged, so its age recipient (`age1uur583...`) stays valid across the reinstall.

Correction from the repair review: Zao's current trusted-key list contains `korri-cache-fuji-1`, not this legacy `fuji-1` key. Preserving the secret does not prove that current cache consumers trust its signatures. The repair verifies signatures against the pinned legacy public key, with other trust keys and substituters disabled. Zao's trust configuration and Korri's cache-signing policy remain unchanged.

### SSH only over Tailscale

Port 22 is open only on `tailscale0`, as on old Fuji. The kexec installer carries Fuji's Tailscale state, so the install arrives over Tailscale too. Cost: if tailscaled fails, the Oracle serial console is the only way in.

### The builder key is forced to the daemon

The `builder` layer lets Zao's builder key run `nix-daemon --stdio` and nothing else (`restrict,command=...`). Old Fuji gave that key a full shell in a wheel account. Cost: Zao must use `ssh-ng://`; the older `ssh://` protocol runs `nix-store --serve` and is refused.

## Before the install

1. **Zao's builder entry.** An eight-job test before the install sent four jobs to each builder. After the install, commit `de652417` changed Fuji's entry in `unified:features/nix-builders/hosts.nix` to `ssh-ng://simon@fuji`. Zao runs that configuration. Yari remains available while Fuji is offline.
2. **Restore set.** The keep set is at `/home/simon/fuji-keep` on Yari and `~/.local/share/mountainous/fuji-keep-2026-10-13` on Zao. Both passed the same checks. Paths inside are under `/home/simonwjackson`; restore them under `/home/simon`.
3. **Kexec rehearsal.** The systemd shutdown path reached the RAM installer on 2026-10-14. SSH through `100.69.49.119` verified the same node key, IPs and SSH host key. The ESP and XFS UUIDs were unchanged and XFS was unmounted. Fuji then rebooted to the exact recorded old system in 49 seconds, with no kernel I/O errors. The wrapper itself timed out because the installer changed the node's MagicDNS name. Use the stable IP and `MOUNTAINOUS_INSTALL_HOST_KEY_ALIAS=fuji.hummingbird-lake.ts.net` for subsequent runs, retaining strict host-key checks.

## Steps

| Step | State |
| --- | --- |
| 1. Inventory services and data | Done 2026-10-13 |
| 2. Copy the keep set to Yari and Zao | Done 2026-10-13 |
| 3. Port the host: permafrost, builder, signing key, Korri cache, Tailscale-only SSH | Done. `checks.fuji-host` passes, `fuji` evaluates |
| 3a. Choose services | Done 2026-10-13: builder only |
| 4. Build Fuji's system | Done. Installed output: `/nix/store/x9c83gs8d7amsjw6162nn3whkqymxiyv-nixos-system-fuji-26.11.20260923.4975466` |
| 5. Before-the-install items 1 to 3 | Done. Keep set, verified serial console, orderly kexec rehearsal, and Zao builder login cutover. |
| 6. Install with `nix run .#install -- fuji <target>` | Done 2026-10-14 in 257 seconds, from `28e67496`. First boot preserved SSH identity and Tailscale IP. |
| 7. Reboot twice and verify the repaired system | Done. Reboots took 69 and 54 seconds, including verification. Exact system, node ID/key, restored IPv4, SSH key, persisted home and secrets, and zero failed units verified each time. |
| 8. Restore the keep set | Done. 41,353 retained home and metadata files match the source digest, including after both reboots. Legacy dot directories remain inactive under `/home/simon/.local/share/fuji-recovery-2026-10-14/legacy-home`. |
| 9. Verify real builds and signatures after reboot | Done. Eight new aarch64 derivations ran through Zao's configured builders: four on Fuji and four on Yari. All four Fuji signatures verified against the preserved public key alone. |

## Retained-data restoration

The active personal folders and retained code are under `/home/simon`. Git bundles and the copy manifest are under `/home/simon/.local/share/fuji-recovery-2026-10-14/meta`. The regular-file digest before staging and after restoration is `e212732292415b5b02470db27fb3cfa00d7ec89aa029163d6982fe62febc242f`, over 41,353 files. Both source backups remain unchanged.

Old `.config`, `.local`, and `.ssh` directories remain in the private `legacy-home` recovery directory. Old `authorized_keys`, client configuration, and PulseAudio runtime links were not activated. System identities and Tailscale state from the backup were not copied into the user home.

The keep set contains filtered recovery material, not complete working checkouts. Incremental bundles can require remote history. Some worktree `.git` files point at old paths. The copied `sandbox/electron-test` Git directory retains its pre-existing missing empty-tree object. `RESTORED.md` in the recovery directory explains these limits.

## Tailscale registration incident

The verification reboot on 2026-10-14 booted the expected installed output and mounted `@tailscale` correctly. The join service nevertheless removed device `1686527239378143`, then logged out and registered again. The journal records `NoState` during daemon startup, followed by `Starting` and `Running`. The join program read local state, name, and public key from separate snapshots and treated an incomplete identity as permission to delete a registration.

The new device is `7789525530584152`, with public node key `nodekey:a1bee18b931f34cd57b2f887cf22b6450857be481838508cde630d5267464f71`. It initially received `100.70.79.113`. The operator approved restoring the old IPv4 `100.69.49.119` to this existing device only if the address was free. Restoring an address does not recover the deleted registration or its original node key.

Commit `28611d96` removes all automatic deletion and logout paths. It reads coherent daemon snapshots, accepts an existing running identity without OAuth or `up`, and fails closed on ambiguous state or name collisions. Name recovery now requires operator review.

The repaired output `/nix/store/l37398l33x3ypj268q1m0bgpwhv19vi7-nixos-system-fuji-26.11.20260923.4975466` was activated on Fuji. The first transient activation attempt omitted `PATH` and failed before changes. The corrected launcher sets both `PATH` and `HOME`; activation completed successfully.

The original IPv4 `100.69.49.119` was then assigned to existing device `7789525530584152` through `POST /api/v2/device/7789525530584152/ip`, after checking that the address was unassigned. The API returned HTTP 200. Local CLI and control-plane checks agreed on the restored address and unchanged node key. IPv6 remained `fd7a:115c:a1e0::6738:4f72`. No device was deleted.

The endpoint and payload were checked in the [official Go client](https://github.com/tailscale/tailscale-client-go-v2/blob/main/devices.go); the required `devices:core` scope is listed in [Tailscale's trust-credentials reference](https://tailscale.com/docs/reference/trust-credentials). Only Fuji received the repaired configuration. No other fleet host was rebooted.

## Final verification evidence

Evidence is under `~/.cache/fuji-work/repair.3K4nus/`. The repaired system is pinned to code commit `28611d96` and store path `/nix/store/l37398l33x3ypj268q1m0bgpwhv19vi7-nixos-system-fuji-26.11.20260923.4975466`.

| Check | Result and evidence |
| --- | --- |
| First repaired reboot | Boot ID `861a293b-0773-4486-bad4-d7f1681ba252`; `repaired-boot-1.txt`, `persistence-1.txt` |
| Second repaired reboot | Boot ID `23773bf5-c487-4b77-b93c-8b52bbce2f19`; `repaired-boot-2.txt`, `persistence-2.txt` |
| Cold-start behavior | `join-boot-1.txt` records an incomplete snapshot refused at 23:47:51 UTC, followed by successful retry at 23:48:20 UTC. No deletion, logout, or `up` occurred. |
| Restored data after reboots | `restored-after-reboots.txt`: unchanged digest `e212732292415b5b02470db27fb3cfa00d7ec89aa029163d6982fe62febc242f` over 41,353 regular files; both inactive symlinks verified |
| Builder distribution | `builder-build.log` and `builder-result.txt`: four jobs per builder, using `ssh-ng://simon@fuji` and `ssh-ng://simon@yari` |
| Fuji signing | `builder-signatures.json` and `fuji-signed-outputs.txt`: four outputs verified with only `fuji-1:0mnvKZa4ZzMJgSgFfQLdQzwcdUtiGqZxxcImE/i9wDo=` trusted; extra keys and substituters disabled |
| Default flake check | `flake-check-repair.log` and `.exit`: exit 0; native checks cached from the same tested derivations |
| ARM join regression | `checks.aarch64-linux.tailscale-join` built on Fuji; all eight test groups passed against its actual generated command |
| All-systems evaluation | `flake-check-all-systems.log`: existing aarch64 media-runtime failure from the missing nix-extras aarch64 `nzbfast`; also reproduced on unchanged base `2575be68` |

The original registration remains deleted. IP reassignment recovered only its IPv4, not its original node key or IPv6. Automatic name reclamation is no longer supported. Other hosts were not deployed or rebooted during this repair.

## Known risks

- **Raw kexec hung on both Oracle VMs.** Fuji also hung with an emergency sync/read-only-remount patch. The `systemctl kexec` path passed the VM test and one Fuji rehearsal. This supports using orderly shutdown, but does not establish the kernel-level cause. Fuji uses its own OCI profile and tenancy; its serial console is available through `~/.local/share/mountainous/oci-console/connect-fuji`.
- **MagicDNS changes in the installer.** Keeping Tailscale state preserved the node key and IP, but the installer advertised `nixos-installer`. Connecting by the old hostname caused the wrapper to time out despite the installer being reachable. Use the IP with the original SSH host-key alias.
- **Yuki becomes the only Syncthing peer** for the personal folders (with Usu for `research`). Fuji leaves them, and Yari was reinstalled without Syncthing.
- **`checks.aarch64-linux.media-runtime` fails** with `packages.aarch64-linux.nzbfast` missing. It fails on the commit before this port as well.

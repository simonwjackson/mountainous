# Yari as a Forgerie host: disk layout, impermanence, and reinstall plan

## Status and scope

**Phase 1 (code) and phase 2 (preparation, including the kexec rehearsal) are done. Yari still runs its old XFS system. The install (step 4) waits for operator approval.** Yari becomes a dedicated Forgerie host. It runs the Forgerie UI and many concurrent sessions. It runs no other services and no builds.

This plan replaces Yari's XFS root with btrfs, wipes the system root at every boot, and keeps state in one persistent area called permafrost. The reinstall wipes Yari's only disk. The operator's part of the install must not grow.

Out of scope:

- How Forgerie itself is packaged and started on Yari. This repository does not declare Forgerie today. It runs on Zao as user units (`forgerie-sessiond`, `forgerie-web`, `forgerie-tsnet`).
- The fleet-wide gap in `tailscale-join` (see [Known risks](#known-risks)). It is a separate fix.

## Facts this plan depends on

All facts were read on Yari or Zao on 2026-10-12.

| Fact | Value | Source |
| --- | --- | --- |
| Machine | Oracle Ampere A1 VM, QEMU/KVM, 4 Neoverse-N1 cores at 2.0 GHz, 23 GiB RAM, no swap | `lscpu`, `free` on Yari |
| Disk | 200 GB boot volume. 512 MB ESP and 199.5 GB XFS root. 3.3 GB used, 3.1 GB of it in `/nix` | `lsblk`, `du` on Yari |
| TPM and Secure Boot | Neither is present | `bootctl status`: "TPM2 Support: no", "Secure Boot: disabled (unsupported)" |
| vTPM on this shape | Not available. Oracle shielded instances list only Intel and AMD shapes and do not support custom images. | Oracle shielded-instance documentation |
| Disk encryption at rest | Oracle encrypts all boot volumes with AES | Oracle Block Volume encryption documentation |
| Disk speed | 101 MB/s sequential write, 94 MB/s sequential read, about 12,000 random 4K IOPS, 1,025 fsync writes per second | fio with direct I/O on Yari |
| Compression speed | zstd level 1 on one core: 429 MB/s on store data. Random data: 3,688 MB/s | zstd benchmark on Yari |
| Forgerie data on Zao | 157 GB in `~/.local/share/forgerie` and 63 GB in `~/.pi`. 227 GB of it is `.jsonl` transcripts. 6.6 GB is SQLite. | `du`, `find` on Zao |
| Transcript compression | zstd level 1: 2.4x. In 128 KiB blocks like btrfs: 2.3x | 1 GB random sample on Zao |
| Free tier | Yari's shape matches the Always Free limits of 4 OCPU, 24 GB RAM, and 200 GB storage. More disk will cost money. | Inferred. The limits were not rechecked in the Oracle console. |

## Decisions

### No disk encryption

Yari has no TPM, so unattended LUKS unlock is not possible. A passphrase at boot would lock Yari out after every Oracle maintenance reboot. Clevis and Tang would make boot depend on the home network. Oracle already encrypts the volume at rest. LUKS does not protect against Oracle itself, because the key stays in RAM that the hypervisor can read.

Cost: a person with Oracle-side access to the running VM can read the data. LUKS would not stop that either.

### btrfs, not bcachefs or XFS

btrfs is in the mainline kernel. Any Linux rescue image can mount it, which matters for a remote VM whose only recovery paths are the serial console and attaching the volume to another instance. zstd level 1 compression makes 220 GB of Forgerie history fit on a 200 GB disk, at about 96 GB. It also makes transcript writes faster, because the CPU compresses about 4 times faster than the disk writes.

bcachefs would match Unzen. Its background recompression gains only about 10 GB on this data (2.6x against 2.3x). Its out-of-tree module and the lack of bcachefs on Oracle rescue images make recovery harder.

Cost: copy-on-write fragments files with many small random writes. The per-session SQLite files are that workload.

### nocow for Forgerie SQLite state (deferred to phase 5)

Each session keeps `state.sqlite` under `.durable/` folders in `~/.local/share/forgerie/agent/sessions/`. Each commit waits on fsync, which already takes about 1 ms on this volume.

Forgerie creates the `.durable` folders inside each project folder at run time. A nocow flag on a parent folder would also stop compression of the transcripts, which are most of the data. So nocow is set when Forgerie is declared on Yari, by Forgerie or by a unit that knows its paths.

Cost: those files, about 6.6 GB today, lose btrfs checksums and compression.

### Impermanence with a permafrost area

The system root is wiped at every boot. Only declared paths survive. Agents run shell commands on this host, so this stops hand-made changes from building up outside the flake. The persisted list is also the backup list.

`/nix` and `/home` persist whole. Forgerie data, checkouts, and agent tool caches live in `/home/simon`, so a per-path list for home would break easily.

The name permafrost is kept. Rakku's implementation in `disks/rakku-existing.nix` is not copied. It is a reference only.

### Tailscale state is protected by design, not by recovery

A lost Tailscale state is a lockout. The rejoin path is not a safety net (see [Known risks](#known-risks)). So:

1. `/var/lib/tailscale` is its own btrfs subvolume, mounted directly. It is not a symlink or bind mount into the wiped root.
2. `tailscaled` gets `RequiresMountsFor=/var/lib/tailscale`. If the mount fails, Tailscale does not start and cannot create a new identity over the old one.
3. sshd and sops read the host key at `/permafrost/etc/ssh/ssh_host_ed25519_key` directly. `/permafrost` mounts in the initrd, so the key exists before sops runs. No bind mount has to be set up first.
4. The kexec installer (`modules/kexec-installer.nix`) copies the running machine's `tailscaled.state` into RAM. The installer comes back on the tailnet as `yari`, with the same address and SSH host key, so the install stays reachable.
5. `nix run .#install` copies the same state into `@tailscale` when the target already reports hostname `yari`. Yari keeps its node key and its address `100.65.213.32`. `tailscale-join` then sees a running, verified node and exits without a new login.

### Swap and memory

zram swap is on. Yari has no swap today. Without it, a memory spike can make the out-of-memory killer stop `forgerie-sessiond` and every session in it. The tmpfs root is capped at 4G, so a runaway write fails instead of pushing out sessions. `/tmp` is a separate tmpfs from the base layer.

## Layout

```
sda1  ESP, vfat, 1 GB, /boot
sda2  btrfs, compress=zstd:1, noatime
  @nix        /nix
  @home       /home                (Forgerie state)
  @permafrost /permafrost          (neededForBoot)
  @tailscale  /var/lib/tailscale   (tailscaled requires this mount)
/   tmpfs, size=4G, wiped at every boot
```

There is no `@snapshots` subvolume yet. Nothing uses it. Add it with the backup design.

Permafrost holds:

| Path | Why it must persist |
| --- | --- |
| `/permafrost/etc/ssh/ssh_host_ed25519_key` | SSH identity and the sops age key, read in place |
| `/etc/machine-id` | Journal and systemd identity |
| `/var/lib/nixos` | Stable UID and GID allocation |
| `/var/log` | Logs across reboots, needed to debug a failed boot |
| `/var/lib/systemd/timers`, `/var/lib/systemd/coredump` | Timer catch-up and crash dumps |

## Install procedure

The agent runs every step. The operator approves step 4.

| Step | Status |
| --- | --- |
| 1. Copy Yari's ed25519 host key to `~/.local/share/mountainous/hostkeys/yari/` | Done. Its age form matches `.sops.yaml`. |
| 2. Recreate the Oracle serial console from Zao with the OCI CLI | Done. It reached `yari login:`. Connect with `~/.local/share/mountainous/oci-console/connect`. |
| 3. Rehearse kexec only: `MOUNTAINOUS_INSTALL_PHASES=kexec nix run .#install -- yari root@yari.hummingbird-lake.ts.net` | Done 2026-10-12. The installer came back on Tailscale as `yari` with the same node key, address and SSH host key, and left the disk unmounted. A reboot returned Yari to XFS with no failed units. |
| 4. Install: `nix run .#install -- yari root@yari.hummingbird-lake.ts.net` | Needs operator approval. Destroys the disk. |
| 5. Reboot twice. Verify the same Tailscale address, SSH with the same host key, decrypted sops secrets, and no failed units. | Pending |
| 6. Declare Forgerie on Yari and copy live sessions from Zao | Pending (phase 5) |

If the installer in step 3 does not come back, reset the instance with `oci compute instance action --action RESET --profile yari`. Yari then boots its old system from disk. If step 5 fails, connect through the serial console and select the earlier boot entry or fix in place. There is no rollback to the XFS system after step 4.

## Verification

| Check | How |
| --- | --- |
| Persistence wiring | `checks.x86_64-linux.permafrost` (passes): installs the real layout, reboots, and verifies the Tailscale machine key, SSH host key, machine-id, `/home` and the journal survive, while files in `/etc`, `/var/lib` and `/root` are gone |
| Mount guard | Same test: with `@tailscale` unmounted, starting `tailscaled` mounts it first and keeps the same key |
| Installer keeps identity | `checks.x86_64-linux.kexec-installer` (passes): kexecs a VM into the installer and verifies the same Tailscale machine key and SSH host key |
| Real boot | Two reboots on Yari, checks from step 5 |
| Forgerie | UI loads through `forgerie-tsnet`, several sessions run at once, a session survives a reboot |

## Open decisions

1. **Where Forgerie history lives.** Live sessions only (about 58 GB compressed) or the full 220 GB (about 96 GB compressed).
2. **Where agent work runs.** Forgerie runs session tool commands on the host. If checkouts move to Yari, agents will run git, nix, and tests on 4 cores. This conflicts with "no compilers on Yari".

Settled: the root is a tmpfs with a size cap. The installer is `nix run .#install` with the fleet kexec installer.

## Known risks

- **The rejoin path cannot recover lost state (all hosts).** If a host loses its Tailscale state while its old node is still listed, `tailscale-join` has no node key to prove the old node is stale. It refuses to delete the old node (`modules/tailscale.nix:92`) and retries forever. This is read from the code and not tested.
- **The VM test cannot prove Oracle boot.** Only the serial console covers a first boot that fails on real hardware.
- **A missed persisted path is lost at the next reboot.** Hand fixes on Yari outside persisted paths also disappear. This is intended, but it will surprise someone once.
- **Backup mirror.** `docs/plans/media-portability.md` says Yari keeps Fuji's mirror at `/var/lib/borg-mirror`. That path does not exist on Yari. Resolve this before Yari becomes a backup target again.

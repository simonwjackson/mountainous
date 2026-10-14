# Fuji on permafrost: port and reinstall plan

## Status and scope

**Phase 1 (config) is written and evaluates. Fuji still runs its old XFS system from the `unified` branch.** The install waits for the steps in [Before the install](#before-the-install) and for operator approval.

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

`secrets/hosts/fuji.yaml` holds the `fuji-1` Nix signing key, so Korri's cache and Zao keep trusting Fuji's builds. It also keeps the Syncthing cert and key, unused for now. Fuji's SSH host key is unchanged, so its age recipient (`age1uur583...`) stays valid across the reinstall.

### SSH only over Tailscale

Port 22 is open only on `tailscale0`, as on old Fuji. The kexec installer carries Fuji's Tailscale state, so the install arrives over Tailscale too. Cost: if tailscaled fails, the Oracle serial console is the only way in.

### The builder key is forced to the daemon

The `builder` layer lets Zao's builder key run `nix-daemon --stdio` and nothing else (`restrict,command=...`). Old Fuji gave that key a full shell in a wheel account. Cost: Zao must use `ssh-ng://`; the older `ssh://` protocol runs `nix-store --serve` and is refused.

## Before the install

1. **Zao's builder entry.** In `unified`, `features/nix-builders/hosts.nix` sends aarch64 work to `simonwjackson@fuji`. Change it to `simon` and deploy Zao, or Zao's aarch64 builds fail after the reinstall.
2. **Restore set.** The keep set is at `/home/simon/fuji-keep` on Yari and `~/.local/share/mountainous/fuji-keep-2026-10-13` on Zao. Both passed the same checks. Paths inside are under `/home/simonwjackson`; restore them under `/home/simon`.
3. **Kexec rehearsal.** `MOUNTAINOUS_INSTALL_PHASES=kexec nix run .#install -- fuji simonwjackson@fuji` with SSH in, as on Yari. Then confirm Fuji comes back as itself on Tailscale.

## Steps

| Step | State |
| --- | --- |
| 1. Inventory services and data | Done 2026-10-13 |
| 2. Copy the keep set to Yari and Zao | Done 2026-10-13 |
| 3. Port the host: permafrost, builder, signing key, Korri cache, Tailscale-only SSH | Done. `checks.fuji-host` passes, `fuji` evaluates |
| 3a. Choose services | Done 2026-10-13: builder only |
| 4. Build Fuji's system | |
| 5. Before-the-install items 1 to 3 | |
| 6. Install with `nix run .#install -- fuji <target>` | Needs operator approval. Destroys the disk |
| 7. Reboot twice, verify as on Yari, restore the keep set | |

## Known risks

- **`kexec -e` hung once on Yari** before disko ran. An OCI reset recovered it. Fuji's instance is in the same tenancy.
- **Yuki becomes the only Syncthing peer** for the personal folders (with Usu for `research`). Fuji leaves them, and Yari was reinstalled without Syncthing.
- **`checks.aarch64-linux.media-runtime` fails** with `packages.aarch64-linux.nzbfast` missing. It fails on the commit before this port as well.

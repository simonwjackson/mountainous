# Host definition: Myoko

## Purpose

Myoko is the ASUS Zenbook A16 UX3607OA. It uses Qualcomm's Glymur platform and boots Linux from devicetree.

## Layering

The host imports `base`, `desktop`, `glymur`, and `myoko-disk`.

It does not import the shared `disk` layer. That layer recreates the whole partition table, which would erase the Qualcomm platform partitions on this machine.

## Verified factory disk layout

The internal drive is a 512 GB Samsung MZVL8512HFLU-00BTW with serial `S7X8NX0L344749`. Partitions 1 to 11 contain platform firmware, logs, and update data. Partition 12 is the factory 450 MiB ESP. See `docs/decisions/glymur.md` for the complete table and backup location.

The installer preserves partitions 1 to 12. It deletes only the four Windows partitions after them.

The installed layout uses:

| Partition | Purpose |
|---:|---|
| 12 | Existing 450 MiB ESP, mounted at `/efi` |
| 13 | New 4 GiB XBOOTLDR FAT32 filesystem, mounted at `/boot` |
| 14 | Remaining space as unencrypted Btrfs, with subvolumes for `/`, `/home`, and `/nix` |

XBOOTLDR keeps kernels and initrds out of the small factory ESP. Systemd-boot stores only its EFI loader in the ESP.

The firmware rejects creation of a new `Boot####` variable with `Input/output error`. Its existing `Boot0002` entry points to `EFI/Microsoft/Boot/bootmgfw.efi` on partition 12. The guarded installer preserves that file as `bootmgfw.efi.windows-original`, then puts the same verified systemd-boot binary at the systemd, removable fallback, and existing firmware paths. This makes the existing firmware entry deterministic without deleting or rewriting it.

## Root encryption deferred

The current installation uses unencrypted Btrfs after a user-approved partition 14 reinstall. The recommendation to remove LUKS relied on an incorrect diagnosis of the boot failure. The unencrypted boot still waits for the root partition's device path, before mounting Btrfs. Recovery could access partition 14; that did not prove the installed initrd could discover it.

Read-only inspection then found two required storage supplier modules absent from the installed initrd: `tcsrcc-glymur` and `phy-qcom-qmp-pcie`. Recovery loads both from its RAM-backed system. Its live device links connect the NVMe PCIe controller to that PHY and the PHY to the TCSR clock. The kernel builds both as modules. The installed kernel and DTB match recovery's files byte-for-byte. This establishes an initrd packaging defect, not a need to remove encryption. Adding those two modules resolved the root-device wait in the subsequent internal boot.

The screen also goes dark after about 30 seconds. Its cause is not established. The configured five-minute console blanking service runs after root is mounted and does not explain that early blackout.

This decision removes encryption at rest. It does not weaken the preserved Qualcomm partitions or the recovery backup. Adding encryption later requires a migration or another partition 14 reinstall.

`scripts/test-myoko-root` formats a disposable loop device as Btrfs, creates the three subvolumes, remounts `@`, and verifies a cold mount without touching the NVMe drive.

## Installation status

Generation 2 completed an internal boot with `/`, `/home`, and `/nix` on partition 14. SSH verified the expected system `/nix/store/ml4ap4jsy0vsn11ylyywk558sa82wq76-nixos-system-myoko-26.11.20260916.b1b8759`. The user confirmed reaching the desktop.

Runtime inspection found a Hyprland session for `simon`, the Samsung `ATNA60HR07-0` panel at 2880x1800 and 120 Hz, active display-loading and greetd services, and zero failed system units. The console blanking service completed successfully and `oled-idle.service` is active. Actual idle blanking and wake behavior still need observation; active services alone do not verify that behavior.

`scripts/test-myoko-initrd <matching-kernel-config> <initrd>` checks the actual boot archive for the NVMe, PCIe, TCSR clock, PCIe PHY, and Btrfs drivers unless they are built in. It fails on the installed image missing the two supplier modules. This is an artifact test, not a substitute for booting the laptop.

## Installation guard

`scripts/install-myoko-target check` verifies the disk serial, sector size, sector count, disk GUID, and GPT integrity. For every preserved partition it verifies the label, PARTUUID, type GUID, start sector, sector count, and GPT attribute flags. Installation refuses any layout other than the verified factory layout or the exact target geometry.

The factory destructive mode requires `MYOKO_ERASE_WINDOWS` to equal the NVMe serial. Reformatting an existing partition 14 requires the separate `MYOKO_REFORMAT_ROOT` guard. `scripts/install-myoko` supplies either value only after it verifies the raw partition images, GPT backup, captured layout, probe report, and myoko host key.

`scripts/test-myoko-partition-plan` restores the GPT backup into a disposable sparse image, applies the partition change, and compares the full `sgdisk -i` record for partitions 1 to 12 before and after. It also verifies the exact new partition geometry.

## PCIe ASPM is not forced

Commit `62f46ec6` added `pcie_aspm=force` and `pcie_aspm.policy=powersupersave` to `boot.kernelParams`, and `myoko-power-sync` wrote `powersupersave` on battery. On 2026-09-20 a native kernel build on battery (91 %) ran for four minutes, then the NVMe root port `0005:00:00.0` logged an AER storm: 223 correctable `RxErr` errors on the root port plus about 1,800 rate-limited `Timeout` and `Rollover` data-link errors on the Samsung NVMe `0005:01:00.0` in 90 seconds. The kernel then reported `nvme0: controller is down; will reset: CSTS=0x3`, Btrfs forced `/` read-only, and the machine needed a power cycle. After reboot `btrfs device stats` were all zero and NVMe SMART showed `media_errors 0`, so the drive and filesystem were not at fault. L1.2 exit under sustained I/O was.

The kernel parameters are removed and the battery branch writes `powersave`. `powersave` keeps L0s and L1 but not the L1 substates that the storm points at. The cost is some battery life; the power figures in `62f46ec6` no longer describe this configuration. Do not restore `powersupersave` or `pcie_aspm=force` without a build-length I/O test on battery that shows zero `PCIe Bus Error` lines in `journalctl -k`.

# Myoko early boot: preliminary online research

The installed unencrypted system waits for partition 14's PARTUUID. The photo proves a device wait, not its cause. Removing LUKS did not resolve it. No further device changes were made for this research.

## Sources read

These links were fetched directly from the project authors' repositories. They reference mutable `main` branches, not pinned revisions. Their configuration is evidence of the authors' implementation, not proof that Myoko needs identical settings.

| Source | Verified source content | Limit |
| --- | --- | --- |
| [A16 required kernel configuration](https://github.com/jc372/A16UbuntuBuild/blob/main/config/a16-required.config) | The exact-model project builds early supplier drivers into the kernel, including Glymur clocks, RPMh regulators, interconnects, Qualcomm PCIe, and the PCIe PHY. Its comments explain that the disposable image must boot before a matching initramfs can load modules. | This does not identify a missing dependency in our built kernel. |
| [A16 boot options](https://github.com/jc372/A16UbuntuBuild/blob/main/docs/boot-options.md) | The author distinguishes firmware-framebuffer operation from MSM display operation. `consoleblank=0` applies to the text console. | This file does not explain Myoko's observed 30-second blackout. |
| [A14 NixOS hardware module](https://github.com/chrispouliot/linux-zenbook-a14-arm/blob/main/modules/default.nix) | The related Glymur machine explicitly loads `tcsrcc-glymur`, `phy_qcom_qmp_pcie`, USB PHY modules, `gpi`, and I2C/HID modules in initrd. It also includes `nvme` in available initrd modules. | UX3407NA is not UX3607OA. Its kernel configuration differs. Do not copy its module list without comparing built-in drivers. |
| [A14 README](https://github.com/chrispouliot/linux-zenbook-a14-arm/blob/main/README.md) | The author describes an installed NixOS daily-driver system, but separately labels the complete installer ISO boot as unvalidated and the Arch installation procedure as experimental. | Do not describe every documented installation route as hardware-verified. |

## What follows from this

Early storage support requires checking supplier drivers, not only the NVMe driver. This is a direction for investigation, not a confirmed diagnosis. A supplier already built into Myoko's kernel does not also need an initrd module.

The next read-only comparison must inspect the actual working USB and installed artifacts: kernel configuration, DTB, initrd modules, firmware, and command line. A diagnostic boot must then distinguish absent NVMe enumeration from absent partition identification. Another filesystem reformat cannot establish that distinction.

## Remaining unknowns

- Whether the internal boot enumerates the NVMe controller and disk at all.
- Whether the installed initrd lacks a supplier module or required firmware.
- Whether the two boot paths supply equivalent device trees at runtime.
- What causes the display to go dark after about 30 seconds.

The online sources alone did not establish the cause. The artifact comparison and subsequent hardware test below did.

## Read-only artifact and runtime comparison

Recovery inspection established the following facts:

- The USB system runs Linux `7.3.0-rc3` and sees partition 14 with the configured PARTUUID.
- The installed kernel hash equals recovery's kernel hash: `7712158c6b37799b1141eeed3131d36ce4728da18eed0ed5cb621b6930a78281`.
- The installed DTB file hash equals recovery's DTB file hash: `806f5e291b647e149d19494a04c60fd97773ead88298c06d30d4ccfe4ed1fc0e`. This compares files, not the failed boot's live tree.
- `/proc/config.gz` reports `CONFIG_CLK_GLYMUR_TCSRCC=m` and `CONFIG_PHY_QCOM_QMP_PCIE=m`. Both corresponding modules are loaded in recovery.
- Recovery's sysfs supplier links connect PCIe controller `1b40000.pcie` to PHY `1b50000.phy`, and that PHY to clock controller `1fd5000.clock-controller`. Their drivers are `qcom-qmp-pcie-phy` and `tcsrcc-glymur`.
- The installed initrd, copied from XBOOTLDR mounted read-only, contains neither `tcsrcc-glymur.ko` nor `phy-qcom-qmp-pcie.ko`. Its SHA-256 is `a8406ae9acc8cc5817aff8c51ac4767c7beee1a6040033c1f8e7f1de78a1690d`.

This establishes an early-storage packaging defect. Recovery loads the missing suppliers after switching to its RAM-backed system. The internal installation cannot use that path because it needs those suppliers before mounting its system.

The archive regression test `scripts/test-myoko-initrd` fails on the old initrd with both `MISSING_FROM_INITRD` results. It passes on the rebuilt initrd. The rebuilt system is `/nix/store/ml4ap4jsy0vsn11ylyywk558sa82wq76-nixos-system-myoko-26.11.20260916.b1b8759`. Kernel, matching modules, DTB, and command line remain unchanged. The subsequent internal hardware boot resolved the observed wait: SSH verified the expected system and Btrfs root on `/dev/nvme0n1p14[/@]`. The user confirmed reaching the desktop. Runtime inspection found Hyprland driving `eDP-1` at 2880x1800 and 120 Hz, active greetd and display-loading services, and zero failed system units.

The five-minute OLED idle service is active, but its actual blanking and wake behavior has not been observed. The earlier blackout's mechanism remains unproven. Removing LUKS was not the fix for the root-device wait.

Raw inspection output and copied boot artifacts are temporarily stored at `/tmp/myoko-boot-evidence-local` on the build host. These temporary files are not durable backups.

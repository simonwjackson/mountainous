# Glymur: booting the Snapdragon X2 Elite laptop

## Purpose
Bring up myoko, an ASUS Zenbook A16 (UX3607OA) on Qualcomm's Glymur platform, without bricking it and without losing firmware that exists in exactly one place.

## Devicetree, not ACPI
The UEFI on this machine publishes ACPI tables for Windows. Linux drives Qualcomm laptops from a devicetree, so the kernel has to be handed one or it does not know what the hardware is. Every boot path below is chosen around that single requirement.

## Kernel floor is 7.3
The board devicetree, `qcom/glymur-asus-zenbook-a16-ux3607oa.dts`, landed in Linux 7.3 as commit `e8fbbca94db7`. No earlier release can describe this laptop. `linux_testing` is 7.3-rc3 as of nixpkgs `b1b8759`, which is why the nixpkgs pin moved from March to September 2026.

## Two patches the panel needs
Mainline 7.3-rc3 programs the v8 eDP PHY with one shared case for HBR2 and HBR3:

```c
	case 5400:
	case 8100:
		hsclk_sel = 0x2;
		dec_start_mode0 = 0x4f;
```

The panel in this laptop advertises HBR2 as its maximum, so the link trains at the rate the PHY mis-programs and the screen stays dark. Bjorn Andersson's two-patch series, posted 2026-06-22 and still not in mainline, gives HBR2 its own PLL programming. A reporter on this exact model confirmed a native 2880x1800 at 120 Hz link with them applied.

Both patches are carried in `modules/glymur/` and were checked to apply to `v7.3-rc3` before being committed.

## CPUCP mailbox must be built in
`arm64` defconfig builds `QCOM_CPUCP_MBOX` as a module. On Glymur it then loads after SCMI has already timed out, and no CPU gets a frequency governor. Reported during the HP EliteBook X G2q bring-up on the same SoC, so `structuredExtraConfig` forces it in.

## Why the probe is a UKI and not the installer ISO
The ISO in this tree boots through GRUB, and nixpkgs' ISO builder has no option to pass a devicetree. A Unified Kernel Image solves it structurally: nixpkgs already wires `hardware.deviceTree` into the UKI's `DeviceTree` PE section, so kernel, initrd, command line and devicetree arrive as one file that the firmware loads from `\EFI\BOOT\BOOTAA64.EFI`.

The Nix store rides inside the initrd, netboot style, so the USB stays a single FAT32 partition. That matters because the same stick carries the firmware extracted from Windows, and installing the probe is a file copy rather than a reformat.

Cost: the image is large for an EFI binary, and firmware must load all of it before the stub runs. If the machine hangs on the vendor logo, suspect the size first and fall back to systemd-boot with a separate kernel, initrd and `devicetree` line.

## Firmware: what exists where
Extracted from the Windows driver store, and nowhere else to be found:

| File | Package |
|---|---|
| `qcadsp8480.mbn`, `adsp_dtbs.elf`, `adspr.jsn`, `adsps.jsn`, `adspua.jsn` | `qcsubsys_ext_adsp8480.inf` |
| `qccdsp8480.mbn`, `cdsp_dtbs.elf` | `qcnspmcdm8480.inf` |

`linux-firmware` has Glymur GPU zap and video firmware at `qcom/glymur/gen80100_zap.mbn` and `qcom/vpu/vpu36_p4_s7.mbn`. Their sizes match the Windows files `qcdxkmsuc8480.mbn` and `qcvss8480.mbn`. A size match alone does not prove that the files are identical.

Wi-Fi board data is in `qcwlanhmt8480.inf` and `qcwlancol8480.inf` as dozens of `bdwlan*` files. The ath12k board file for this laptop was still in review upstream in September 2026, so these are the raw material for building one.

## SoCCP is not extractable, and does not need to be
`soccp.mbn` and `soccp_dtb.mbn` are absent from the driver store. The Windows INF explains why:

```
HKR,SOCCP,"SubsysUefiLoadedImageAction",%REG_DWORD%,0x1
HKR, LiveHandoff\SOCCP,"UefiLoadedImageTZProcID",%REG_DWORD%,0x33
```

UEFI loads the SoC Control Processor and the OS performs a live handoff. Linux does the same. `glymur_soccp_resource` in `qcom_q6v5_pas.c` sets `.early_boot = true`, and probe reacts to that with `pas->rproc->state = RPROC_DETACHED` — the kernel adopts a processor the bootloader already started. The firmware names are only used to reload it after a crash, so their absence costs subsystem restart, not USB-C or charging.

## Do not erase the whole disk
The laptop has one internal disk. Windows reports sixteen partitions on it. The first eleven are small, use types Windows does not recognise, and sit before the 450 MB ESP: 1 MB, 16 MB, 1 MB, 1 MB, 70 MB, 120 MB, 120 MB, 1 MB, 1 MB, 1 MB, 512 MB.

Qualcomm systems often store platform firmware in partitions like these. Linaro documents the failure mode when an installer erases such a disk: "if you allow the installer to erase the disk, your board will NO LONGER BOOT." We have not verified the names or contents of this machine's eleven partitions yet.

The probe must read the real GPT labels before any install layout is written. Until then, preserve partitions 1 to 11 and avoid `mountainous.disk`, because it owns the whole partition table. Whether the final install reuses the existing ESP also depends on that inspection.

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

Already upstream in `linux-firmware`, confirmed by byte-identical size: the GPU zap shader (`qcdxkmsuc8480.mbn`, 12,088 bytes, ships as `qcom/glymur/gen80100_zap.mbn`) and the video firmware (`qcvss8480.mbn`, 2,503,368 bytes, ships as `qcom/vpu/vpu36_p4_s7.mbn`).

Wi-Fi board data is in `qcwlanhmt8480.inf` and `qcwlancol8480.inf` as dozens of `bdwlan*` files. The ath12k board file for this laptop was still in review upstream in September 2026, so these are the raw material for building one.

## SoCCP is not extractable, and does not need to be
`soccp.mbn` and `soccp_dtb.mbn` are absent from the driver store. The Windows INF explains why:

```
HKR,SOCCP,"SubsysUefiLoadedImageAction",%REG_DWORD%,0x1
HKR, LiveHandoff\SOCCP,"UefiLoadedImageTZProcID",%REG_DWORD%,0x33
```

UEFI loads the SoC Control Processor and the OS performs a live handoff. Linux does the same. `glymur_soccp_resource` in `qcom_q6v5_pas.c` sets `.early_boot = true`, and probe reacts to that with `pas->rproc->state = RPROC_DETACHED` — the kernel adopts a processor the bootloader already started. The firmware names are only used to reload it after a crash, so their absence costs subsystem restart, not USB-C or charging.

## Do not erase the whole disk
The laptop has one internal disk. Windows reports sixteen partitions on it, the first eleven small and of a type Windows does not recognise, sitting ahead of the 450 MB ESP: 1 MB, 16 MB, 1 MB, 1 MB, 70 MB, 120 MB, 120 MB, 1 MB, 1 MB, 1 MB, 512 MB. That is the Qualcomm firmware set, and the UEFI that boots this machine lives among it.

Linaro states the failure mode for exactly this layout: where firmware shares the disk with the OS, "if you allow the installer to erase the disk, your board will NO LONGER BOOT." Recovery means EDL mode and a vendor image.

So the install must keep partitions 1 to 11, reuse the existing ESP, and claim only the Windows partitions after it. `mountainous.disk` describes a whole drive and therefore cannot be used on this machine as written.

Partition names are unverified at the time of writing: Windows only reports sizes and calls the type Unknown. Reading the real GPT labels is the first job of the probe image.

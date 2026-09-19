# Glymur: booting the Snapdragon X2 Elite laptop

## Purpose
Bring up myoko, an ASUS Zenbook A16 (UX3607OA) on Qualcomm's Glymur platform, without bricking it and without losing firmware that exists in exactly one place.

## Devicetree, not ACPI
The UEFI on this machine publishes ACPI tables for Windows. Linux drives Qualcomm laptops from a devicetree, so the kernel has to be handed one or it does not know what the hardware is. Every boot path below is chosen around that single requirement.

## Kernel floor is 7.3
The board devicetree, `qcom/glymur-asus-zenbook-a16-ux3607oa.dts`, landed in Linux 7.3 as commit `e8fbbca94db7`. No earlier release can describe this laptop. `linux_testing` is 7.3-rc3 as of nixpkgs `b1b8759`, which is why the nixpkgs pin moved from March to September 2026.

## Four patches the panel path needs
The reproducible same-model reference is `jc372/A16UbuntuBuild` at commit `3de6f0a4921641dde5fae0e912725821b7396c55`. It reports Linux `7.3.0-rc3-next-20260914` on the UX3607OA with the internal panel at 2880x1800 and both 120 Hz and 60 Hz modes. The reviewed details are in `docs/research/ux3607oa-linux-reference.md`.

The reference carries Bjorn Andersson's two-patch v8 eDP PHY series. Those patches correct rate-specific and lane-specific programming. They do not make this panel train at its advertised four-lane HBR2 rate. The report records successful clock recovery followed by a channel-equalization timeout at HBR2.

Two more patches complete the working path:

- An HBR3 override selects the 8.1 Gbit/s rate allowed by the device tree. The panel then trains and exposes its 2880x1800 modes.
- A failed-enable guard skips `PUSH_IDLE` when the link never came up. The report says the unguarded disable path can trigger a TrustZone SOCCP/ADSP force-stop and a silent SoC reset.

All four patches are carried in `modules/glymur/`. The two PHY patch bodies match the same-model reference. This corrects the earlier claim that the PHY series alone produced a native HBR2 link.

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

`linux-firmware` 20260910 has the upstream GPU files at `qcom/gen80100_aqe.fw`, `qcom/gen80100_gmu.bin`, `qcom/gen80100_sqe.fw`, and `qcom/glymur/gen80100_zap.mbn`. It has video firmware at `qcom/vpu/vpu36_p4_s7.mbn`. The probe packages only these files instead of adding the 1.9 GiB firmware tree to the UKI.

The Windows files `qcdxkmsuc8480.mbn` and `qcvss8480.mbn` have the same sizes as the upstream zap and video files. A size match alone does not prove that the files are identical.

Wi-Fi board data is in `qcwlanhmt8480.inf` and `qcwlancol8480.inf` as dozens of `bdwlan*` files. The ath12k board file for this laptop was still in review upstream in September 2026, so these are the raw material for building one.

## SoCCP is not extractable, and does not need to be
`soccp.mbn` and `soccp_dtb.mbn` are absent from the driver store. The Windows INF explains why:

```
HKR,SOCCP,"SubsysUefiLoadedImageAction",%REG_DWORD%,0x1
HKR, LiveHandoff\SOCCP,"UefiLoadedImageTZProcID",%REG_DWORD%,0x33
```

UEFI loads the SoC Control Processor and the OS performs a live handoff. Linux does the same. `glymur_soccp_resource` in `qcom_q6v5_pas.c` sets `.early_boot = true`, and probe reacts to that with `pas->rproc->state = RPROC_DETACHED` — the kernel adopts a processor the bootloader already started. The firmware names are only used to reload it after a crash, so their absence costs subsystem restart, not USB-C or charging.

## Do not erase the whole disk
The first Linux probe read the GPT from the 512 GB Samsung drive. The platform partitions are now known:

| Number | Label | Size |
|---:|---|---:|
| 1 | `ToolsFv` | 1 MiB |
| 2 | `LogFs` | 16 MiB |
| 3 | `EnterpriseFV` | 1 MiB |
| 4 | `ToolsFv_BACKUP` | 1 MiB |
| 5 | `UpdateCapsule` | 70 MiB |
| 6 | `NHLOS` | 120 MiB |
| 7 | `core_nhlos_a` | 120 MiB |
| 8 | `quantumsdk` | 1 MiB |
| 9 | `quantumfv` | 1 MiB |
| 10 | `catecontentfv` | 1 MiB |
| 11 | `logdump` | 512 MiB |
| 12 | `EFI system partition` | 450 MiB |

Partitions 13 to 16 are the Microsoft reserved partition, Windows, Windows recovery, and MYASUS recovery. NixOS can reclaim those four partitions without changing partitions 1 to 12.

Raw images of partitions 1 to 11, the GPT, and the first probe report are stored outside the repository at `/persist/backups/myoko-platform-S7X8NX0L344749-2026-09-18`. Every raw image passed its recorded SHA-256 check.

`mountainous.disk` cannot install this machine because it owns the whole partition table. The myoko installer needs a board-specific partition script that deletes only partitions 13 to 16.

## First probe findings
The first probe booted Linux 7.3-rc3 from the DTB-carrying UKI on September 18, 2026. The DT model and compatible strings match `ASUS Zenbook A16 (UX3607OA)` and `qcom,glymur`.

Verified working in that boot:

- The UEFI framebuffer and early internal-panel output.
- NVMe and all sixteen GPT entries.
- The internal keyboard, touchpad, touchscreen, and stylus input devices.
- The Realtek RTL8156 USB Ethernet adapter, even without its optional firmware patch.
- SCMI CPU frequency drivers for policies 0, 6, and 12.
- Battery reporting through `qcom-battmgr`.
- SoCCP late attach.

`/sys/power/mem_sleep` reports `s2idle [deep]`. This corrects the earlier assumption that only s2idle exists. It does not prove that deep sleep works or reaches a useful power state.

The known-good probe has no `CONFIG_CLK_GLYMUR_GPUCC`, so MSM DRM cannot bind. It remains reachable through SSH and uses the firmware framebuffer. A second probe built the GPU clock controller in, but it produced no usable panel or SSH session.

A later probe carried the complete same-model display patch set, built GPUCC in, and tried to delay MSM through `modprobe.blacklist=msm`. It still produced a black panel and no SSH, although the Ethernet interface answered ICMP. It created no USB log, so the system stopped before the multi-user logging service ran. The next probe keeps GPUCC, GXCLKCTL, and MSM as matching modules and blocks all three aliases until logging is active.

The probe also waited twice for TPM devices that firmware advertises but Linux does not expose. Probe TPM support is disabled after the first boot. ADSP, cDSP, Wi-Fi, and the full DRM path still need verification with their firmware present.

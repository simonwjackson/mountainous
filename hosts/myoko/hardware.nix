# ASUS Zenbook A16 (UX3607OA), Snapdragon X2 Elite Extreme, Qualcomm "Glymur".
#
# This file carries only what holds without the machine in hand. The Glymur
# enablement work below is unfinished on purpose: every line of it needs the
# hardware to verify, and a wrong devicetree or firmware path fails at
# activation rather than at evaluation.
#
# Read github.com/FixItFoundry/zenbook-a16-linux first. It is a bring-up of
# this exact model that its author runs daily on Fedora 44, kernel base
# next-20260817 (7.2-rc6) plus a 13-patch series. docs/hardware.md there gives
# a per-component status with a command to check each one.
#
# Verified on 2026-09-16:
#
#   - The board devicetree landed for Linux 7.3 as
#     arch/arm64/boot/dts/qcom/glymur-asus-zenbook-a16-ux3607oa.dts
#     (commit e8fbbca94db7). It builds qcom/glymur-asus-zenbook-a16-ux3607oa.dtb.
#   - cpufreq needs the `arm,no-completion-irq` property on the scmi node.
#     The CPUCP firmware writes SCMI Performance replies into shared memory
#     and never rings the mailbox doorbell, so scmi-cpufreq probes -110 and
#     every CPU stays at boot clock. The property makes the SCMI core poll.
#     Measured with SCMI RAW on a retail A16. Building CONFIG_QCOM_CPUCP_MBOX
#     into the kernel does not fix this on its own.
#   - The internal eDP panel trains at its native HBR2 with the v8 eDP PHY
#     series (change-id 20260622-glymur-edp-phy). Forcing HBR3 was the old
#     workaround and is retired.
#   - ADSP and cDSP auto-boot before the rootfs mounts and do not retry, so
#     their firmware has to be in the initrd, not only on the root filesystem.
#     The board asks for these under qcom/glymur/ASUSTeK/UX3607OA/:
#     qcadsp8480.mbn, adsp_dtbs.elf, qccdsp8480.mbn, cdsp_dtbs.elf,
#     soccp.mbn, soccp_dtb.mbn.
#   - The kernel command line needs
#     `systemd.mask=dev-tpm0.device dev-tpmrm0.device`, or boot stalls for
#     about 90 seconds.
#   - s2idle needs the `glymur_pci_skip=5` workaround. PCI config-space access
#     during dpm_suspend_noirq() resets the SoC. The machine then sleeps with
#     PCI still powered, and xHCI and ath12k do not resume without a recovery
#     hook.
#   - The GPU works under Mesa turnip. The zap shader does not: TrustZone
#     rejects the upstream-signed image, so leave that DT node out.
#   - HDMI, the camera, fan PWM, the headphone jack, and USB4 do not work.
#     The RTC counts but is read-only and has no wake alarm.
#   - The Hexagon NPU is unusable here today. llama.cpp ggml-hexagon opens a
#     session and then hangs at the first compute round-trip on mainline
#     fastrpc: github.com/qualcomm/fastrpc/issues/377, filed from an A16,
#     open. Plan on CPU and Vulkan for local inference.
#
# Turning that into config means pinning a 7.3-or-newer kernel, setting
# hardware.deviceTree, and getting the OEM firmware into
# boot.initrd.extraFirmwarePaths. Do it once the machine can boot and say
# what actually works.
{...}: {
  nixpkgs.hostPlatform = "aarch64-linux";

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi";
      };
    };

    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
  };
}

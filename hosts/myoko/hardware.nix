# ASUS Zenbook A16 (UX3607OA), Snapdragon X2 Elite Extreme, Qualcomm "Glymur".
#
# This file carries only what holds without the machine in hand. The Glymur
# enablement work below is unfinished on purpose: every line of it needs the
# hardware to verify, and a wrong devicetree or firmware path fails at
# activation rather than at evaluation.
#
# Verified upstream on 2026-09-16:
#
#   - The board devicetree landed for Linux 7.3 as
#     arch/arm64/boot/dts/qcom/glymur-asus-zenbook-a16-ux3607oa.dts
#     (commit e8fbbca94db7). It builds qcom/glymur-asus-zenbook-a16-ux3607oa.dtb.
#   - CONFIG_QCOM_CPUCP_MBOX must be built in (=y). arm64 defconfig builds it
#     as a module, and then every SCMI transaction times out and no CPU gets
#     cpufreq.
#   - The internal eDP panel needs the v8 eDP PHY series
#     (change-id 20260622-glymur-edp-phy). Without it the panel stays dark.
#   - ADSP and cDSP auto-boot before the rootfs mounts and do not retry, so
#     their firmware has to be in the initrd, not only on the root filesystem.
#     The board asks for these under qcom/glymur/ASUSTeK/UX3607OA/:
#     qcadsp8480.mbn, adsp_dtbs.elf, qccdsp8480.mbn, cdsp_dtbs.elf,
#     soccp.mbn, soccp_dtb.mbn.
#   - The ath12k board data for this laptop (QCC2072) was still in review.
#   - s2idle did not collapse the CX power domain on linux-next in August 2026.
#     Treat unattended suspend as unproven until measured on this unit.
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

# The Snapdragon X2 Elite (Qualcomm "Glymur") layer.
#
# This machine is driven from a devicetree, not from the ACPI tables its UEFI
# hands out for Windows. Nothing here is a preference: without the devicetree
# the kernel does not know what the hardware is, and without the two patches
# the internal panel stays dark.
#
# Kernel floor is 7.3. The board devicetree for the ASUS Zenbook A16 (UX3607OA)
# landed in that release as commit e8fbbca94db7, so linux_testing is the oldest
# tree that can describe this laptop at all.
{
  nixos.modules.glymur =
    { lib, pkgs, ... }:
    {
      boot.kernelPackages = pkgs.linuxPackagesFor (
        pkgs.linux_testing.override (old: {
          # nixpkgs answers "m" to every driver question it is not told about,
          # which on arm64 means compiling several thousand modules for
          # hardware this laptop does not have: NFC readers, Tegra boards,
          # PCI sound cards. The base config is `make defconfig`, and upstream
          # put the Glymur options into arm64 defconfig when the SoC landed
          # ("arm64: defconfig: Enable Glymur configs for boot to shell"), so
          # turning the automatic pass off leaves the machine described and
          # drops the tail. Anything the probe cannot boot without is named
          # below rather than left to the default.
          autoModules = false;

          # With the automatic pass off, most of nixpkgs' common config is
          # answering questions that no longer exist: CIFS_XATTR without CIFS,
          # SND_HDA_CODEC_CS8409 without HDA, joystick force-feedback without
          # the joysticks. aarch64 treats an unused answer as a hard error, so
          # a trimmed kernel cannot be configured without this. The cost is
          # that a missing option is now silent too, which is what
          # scripts/check-kernel-config exists to catch.
          ignoreConfigErrors = true;

          structuredExtraConfig = with lib.kernel; {
            # arm64 defconfig builds the CPUCP mailbox as a module. On Glymur
            # it then loads after SCMI has already timed out, and no CPU gets
            # a frequency governor. Reported during the HP EliteBook X G2q
            # bring-up on this SoC.
            QCOM_CPUCP_MBOX = yes;

            # The UKI is loaded by the firmware as an EFI application, so the
            # stub is not optional here.
            EFI = yes;
            EFI_STUB = yes;

            # Root, boot medium and the store the initrd carries.
            BLK_DEV_NVME = yes;
            SQUASHFS = yes;
            EXT4_FS = yes;
            VFAT_FS = yes;
            USB_STORAGE = yes;
            USB_XHCI_HCD = yes;
            USB_XHCI_PLATFORM = yes;

            # If msm never lights the panel, the UEFI framebuffer still gives
            # a console to read. That is the difference between a failed boot
            # we can diagnose and one we cannot see.
            DRM = yes;
            DRM_SIMPLEDRM = yes;
            SYSFB_SIMPLEFB = yes;
            FRAMEBUFFER_CONSOLE = yes;

            # The chipset in the USB ethernet adapter is unknown, and the
            # whole autonomous path depends on the link coming up, so carry
            # the common ones rather than guess.
            USB_USBNET = module;
            USB_RTL8152 = module;
            USB_NET_AX8817X = module;
            USB_NET_AX88179_178A = module;
            USB_NET_CDCETHER = module;
            USB_NET_CDC_NCM = module;
            USB_NET_RNDIS_HOST = module;
          };

          kernelPatches = (old.kernelPatches or [ ]) ++ [
            # Mainline's v8 eDP PHY gives HBR2 and HBR3 the same PLL
            # programming. The panel in this laptop advertises HBR2 as its
            # maximum, so the link trains at a rate the PHY mis-programs and
            # the screen never lights. Both patches are Bjorn Andersson's,
            # posted 2026-06-22 and not yet in mainline as of 7.3-rc3; the
            # reporter on this exact model confirmed a native HBR2 link with
            # them applied.
            {
              name = "glymur-edp-phy-split-power-on";
              patch = ./glymur/0001-phy-qcom-edp-split-power-on-sequencing-by-phy-version.patch;
            }
            {
              name = "glymur-edp-phy-v8-power-on";
              patch = ./glymur/0002-phy-qcom-edp-update-v8-power-on-programming-sequence.patch;
            }
          ];
        })
      );

      # systemd-boot writes a `devicetree` line into the boot entry, and the
      # UKI carries the same file in a PE section. Either way this name is
      # what selects the machine.
      hardware.deviceTree = {
        enable = true;
        name = "qcom/glymur-asus-zenbook-a16-ux3607oa.dtb";
      };
    };
}

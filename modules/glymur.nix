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

            # arm64 defconfig builds the CPUCP mailbox as a module. On Glymur
            # it then loads after SCMI has already given up, every SCMI
            # transaction times out, and no CPU gets a frequency governor.
            # Reported against the HP EliteBook X G2q bring-up, same SoC.
            {
              name = "glymur-cpucp-mailbox-builtin";
              patch = null;
              structuredExtraConfig = {
                QCOM_CPUCP_MBOX = lib.kernel.yes;
              };
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

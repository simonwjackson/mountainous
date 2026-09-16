# A system that boots on hardware it has never seen.
#
# This layer is only the difference between a stick and a fixed install. Two
# things change:
#
#  1. The initrd carries drivers for controllers we cannot predict, on top of
#     the baseline in `base`.
#  2. The bootloader installs to the removable fallback path and never writes
#     UEFI variables, so plugging the stick into a laptop does not edit that
#     laptop's firmware.
#
# Firmware and flash-wear settings used to live here. They were never about
# portability, and a fixed host that stopped importing this layer lost them
# silently, so they now sit in `base`.
#
# There is no nixos-facter report. Facter describes one machine, which is the
# opposite of what a portable system wants.
{
  nixos.modules.portable =
    { lib, ... }:
    {
      # Added to the baseline in `base`, not replacing it.
      boot.initrd.availableKernelModules = [
        # USB controllers and mass storage, the path this system boots over.
        "xhci_hcd"
        "ehci_pci"
        "ohci_pci"
        "usb_storage"
        "uas"
        # Removable and optical media on unfamiliar machines.
        "sr_mod"
        "sdhci_pci"
        "rtsx_pci_sdmmc"
        # So the stick also boots inside a virtual machine.
        "virtio_pci"
        "virtio_blk"
        "virtio_scsi"
      ];

      # USB enumeration is slower than an internal disk. Without this the
      # initrd can give up before the root partition appears.
      boot.initrd.kernelModules = [ "usb_storage" ];

      # GRUB in removable mode writes /EFI/BOOT/BOOTX64.EFI, which every UEFI
      # firmware will boot off a stick without an NVRAM entry.
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
      boot.loader.grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "nodev";

        # disko appends the install-time device path here whenever the layout
        # contains an EF02 partition:
        #
        #   lib/types/gpt.nix:
        #     ++ (lib.optional (lib.any (part: part.type == "EF02") ...) {
        #          boot.loader.grub.devices = [ config.device ];
        #        });
        #
        # That path is right while installing and wrong for ever after. The
        # stick is /dev/sdi on the workstation that built it and something
        # else on every machine that boots it, so a later rebuild fails with
        # "cannot find a GRUB drive for /dev/sdi".
        #
        # BIOS core.img is written once during the install and does not need
        # rewriting on a rebuild. Only the EFI loader and grub.cfg change, and
        # those live on the mounted ESP, which needs no device path.
        devices = lib.mkForce [ "nodev" ];
      };

    };
}

# A system that boots on hardware it has never seen.
#
# This is the layer that makes a USB stick a real machine rather than a live
# image. Three things differ from a fixed install:
#
#  1. The initrd carries drivers for controllers we cannot predict, because
#     the stick may be moved between machines.
#  2. The bootloader installs to the removable fallback path and never writes
#     UEFI variables, so plugging the stick into a laptop does not edit that
#     laptop's firmware.
#  3. No nixos-facter report. Facter describes one machine, which is the
#     opposite of what a portable system wants.
{
  nixos.modules.portable =
    { lib, ... }:
    {
      boot.initrd.availableKernelModules = [
        # USB controllers and mass storage, the path this system boots over.
        "xhci_pci"
        "xhci_hcd"
        "ehci_pci"
        "ohci_pci"
        "usbhid"
        "usb_storage"
        "uas"
        # Internal controllers, so the stick can also see local disks.
        "ahci"
        "nvme"
        "sd_mod"
        "sr_mod"
        "sdhci_pci"
        "rtsx_pci_sdmmc"
        # Common laptop storage oddities.
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
      };

      # Flash wears out. Cut the obvious write amplification.
      services.fstrim.enable = true;
      boot.tmp.useTmpfs = true;
      nix.settings.auto-optimise-store = true;
    };
}

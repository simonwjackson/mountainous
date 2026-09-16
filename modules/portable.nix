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

      # Drivers are useless without the blobs they load at probe time.
      #
      # A fixed install gets this from nixos-generate-config or a facter
      # report. A portable system has neither, so it must carry firmware for
      # hardware it has not met. Without it an Intel Iris Xe GPU fails to
      # initialise and opening /dev/dri/cardN returns EINVAL, which looks like
      # a compositor bug and is not one.
      hardware.enableRedistributableFirmware = true;

      # Flash wears out. Cut the obvious write amplification.
      services.fstrim.enable = true;
      boot.tmp.useTmpfs = true;
      nix.settings.auto-optimise-store = true;
    };
}

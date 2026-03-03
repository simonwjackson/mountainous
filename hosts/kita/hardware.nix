{ config, lib, pkgs, ... }:

{
  # Intel NUC8i3BEK (Coffee Lake i3-8109U)
  boot = {
    loader = {
      efi.canTouchEfiVariables = false;
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "/dev/disk/by-id/ata-KINGSTON_SUV500M8240G_50026B7683B6CE9D";
      };
    };

    initrd.availableKernelModules = [
      "xhci_pci"
      "thunderbolt"
      "ahci"
      "nvme"
      "usb_storage"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];

    kernelModules = [ "kvm-intel" ];
  };

  # Intel Iris Plus Graphics 655 (integrated)
  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;

    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver    # LIBVA_DRIVER_NAME=iHD
        intel-vaapi-driver    # LIBVA_DRIVER_NAME=i965
        libvdpau-va-gl
      ];
    };
  };
}

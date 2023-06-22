{ config, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # ./screens.nix
    ../../modules/syncthing.nix
    ../../modules/tailscale.nix
    ../../modules/networking.nix
    ../../profiles/gui
    ../../profiles/audio.nix
    ../../profiles/workstation.nix
    ../../profiles/_common.nix
    ../../users/simonwjackson
  ];

  networking.hostName = "fiji";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/71fdf463-2584-4413-9aed-4c1478a5056a";
    fsType = "btrfs";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/71fdf463-2584-4413-9aed-4c1478a5056a";
    fsType = "btrfs";
    options = [ "subvol=home" "compress=zstd" ];
  };

  fileSystems."/storage" = {
    device = "/dev/disk/by-uuid/71fdf463-2584-4413-9aed-4c1478a5056a";
    fsType = "btrfs";
    options = [ "subvol=storage" "compress=zstd" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/71fdf463-2584-4413-9aed-4c1478a5056a";
    fsType = "btrfs";
    options = [ "subvol=nix" "compress=zstd" "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/7C20-94CC";
    fsType = "vfat";
  };

  swapDevices = [{
    device = "/dev/nvme0n1p2";
  }];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  services.xserver.libinput.enable = true;

  services.syncthing = {
    dataDir = "/home/simonwjackson"; # Default folder for new synced folders

    folders = {
      documents.path = "/home/simonwjackson/documents";
      code.path = "/home/simonwjackson/code";

      documents.devices = [ "fiji" "kuro" "unzen" "yari" ];
      code.devices = [ "fiji" "kita" "unzen" "yari" ];
    };
  };

  system.stateVersion = "23.05"; # Did you read the comment?
}

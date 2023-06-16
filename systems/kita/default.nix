{ config, lib, pkgs, modulesPath, ... }:

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

  networking.hostName = "kita";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/7d40286e-c82d-4340-ae60-8896085c945c";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/7d40286e-c82d-4340-ae60-8896085c945c";
      fsType = "btrfs";
      options = [ "subvol=home" "compress=zstd" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/7d40286e-c82d-4340-ae60-8896085c945c";
      fsType = "btrfs";
      options = [ "subvol=nix" "compress=zstd" "noatime" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/E167-5889";
      fsType = "vfat";
    };
 
  swapDevices = [ ];

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
      documents.devices = [ "kuro" "unzen" "zao" "fiji" ];
      
      code.path = "/home/simonwjackson/code";
      code.devices = [ "kuro" "unzen" "zao" "fiji" ];
    };
  };

  system.stateVersion = "23.05"; # Did you read the comment?
}

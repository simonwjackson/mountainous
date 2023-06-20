{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # ./screens.nix
    # ../../modules/syncthing.nix
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
    {
      device = "/dev/disk/by-uuid/7d40286e-c82d-4340-ae60-8896085c945c";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" ];
    };

  fileSystems."/home" =
    {
      device = "/dev/disk/by-uuid/7d40286e-c82d-4340-ae60-8896085c945c";
      fsType = "btrfs";
      options = [ "subvol=home" "compress=zstd" ];
    };

  fileSystems."/nix" =
    {
      device = "/dev/disk/by-uuid/7d40286e-c82d-4340-ae60-8896085c945c";
      fsType = "btrfs";
      options = [ "subvol=nix" "compress=zstd" "noatime" ];
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/E167-5889";
      fsType = "vfat";
    };

  fileSystems."/home/simonwjackson/code" = {
    device = "unzen:/tank/code";
    fsType = "nfs";
  };

  fileSystems."/home/simonwjackson/documents" = {
    device = "unzen:/tank/documents";
    fsType = "nfs";
  };

  fileSystems."/home/simonwjackson/audiobooks" = {
    device = "unzen:/net/unzen/tank/audiobooks";
    fsType = "nfs";
  };

  fileSystems."/home/simonwjackson/music" = {
    device = "unzen:/net/unzen/tank/music";
    fsType = "nfs";
  };

  systemd.services.ensureNzbgetDownloadDir = {
    script = ''
      install -d -o simonwjackson -g users -m 770 /home/simonwjackson/videos
    '';
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  fileSystems."/home/simonwjackson/videos/series" = {
    device = "unzen:/net/unzen/tank/series";
    fsType = "nfs";
  };

  fileSystems."/home/simonwjackson/videos/films" = {
    device = "unzen:/net/unzen/tank/series";
    fsType = "nfs";
  };

  fileSystems."/home/simonwjackson/gaming" = {
    device = "unzen:/net/unzen/tank/gaming";
    fsType = "nfs";
  };

  fileSystems."/home/simonwjackson/books" = {
    device = "unzen:/net/unzen/tank/books";
    fsType = "nfs";
  };

  fileSystems."/home/simonwjackson/comics" = {
    device = "unzen:/net/unzen/tank/comics";
    fsType = "nfs";
  };

  fileSystems."/home/simonwjackson/downloads" = {
    device = "unzen:/net/unzen/tank/downloads";
    fsType = "nfs";
  };

  fileSystems."/home/simonwjackson/photos" = {
    device = "unzen:/net/unzen/tank/photos";
    fsType = "nfs";
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

  system.stateVersion = "23.05"; # Did you read the comment?
}

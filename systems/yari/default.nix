{ config, lib, pkgs, modulesPath, ... }: {
  imports = [
    ../../hardware/bluetooth.nix
    ../../hardware/nvidia.nix
    ../../modules/networking.nix
    ../../modules/syncthing.nix
    ../../modules/tailscale.nix
    ../../profiles/gui
    ../../profiles/audio.nix
    ../../profiles/workstation.nix
    ../../profiles/_common.nix
    ../../users/simonwjackson
    <nixos-hardware/dell/xps/17-9700/nvidia>
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "usbhid" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  boot.kernelModules = [ "kvm-intel" "uinput" ];
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Includes the Wi-Fi and Bluetooth firmware
  hardware.enableRedistributableFirmware = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  programs.steam = {
    enable = true;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "yari";

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  services.xserver.libinput.enable = true;

  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      # xdg-desktop-portal-wlr
      xdg-desktop-portal-kde
      # xdg-desktop-portal-gtk
    ];
  };


  environment.systemPackages = [
    pkgs.sunshine
    pkgs.pkgs.cifs-utils
    pkgs.xfsprogs
    pkgs.fuse3 # for nofail option on mergerfs (fuse defaults to fuse2)
    pkgs.mergerfs
    pkgs.mergerfs-tools
  ];

  # "/home/simonwjackson/.local/share/Cemu/mlc01" = {
  #   device = "/storage/gaming/profiles/simonwjackson/progress/saves/wiiu/";
  #   options = [ "bind" ];
  # };

  services.syncthing = {
    dataDir = "/home/simonwjackson"; # Default folder for new synced folders

    folders = {
      documents.path = "/home/simonwjackson/documents";
      code.path = "/home/simonwjackson/code";
      # gaming.path = "/storage/gaming";

      # gaming.devices = [ "unzen" "raiden" ];
      documents.devices = [ "kuro" "unzen" "ushiro" "raiden" "yari" ];
      code.devices = [ "unzen" "ushiro" "raiden" "yari" ];
    };
  };

  hardware.xpadneo.enable = true;

  fileSystems."/" =
    {
      device = "/dev/nvme0n1p2";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" ];
    };

  fileSystems."/home" =
    {
      device = "/dev/nvme0n1p2";
      fsType = "btrfs";
      options = [ "subvol=home" "compress=zstd" "noatime" ];
    };

  fileSystems."/nix" =
    {
      device = "/dev/nvme0n1p2";
      fsType = "btrfs";
      options = [ "subvol=nix" "compress=zstd" ];
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/ED99-9177";
      fsType = "vfat";
    };

  # fileSystems."/storage" =
  #   { device = "/dev/disk/by-uuid/905b4626-9364-477c-bdb7-0275d520ce31";
  #     fsType = "btrfs";
  #     options = [ "subvol=storage" "compress=zstd" ];
  #   };
  # 
  #   fileSystems."/home/simonwjackson/.local/share/Steam/steamapps" = {
  #     device = "/storage/gaming/games/steam";
  #     options = [ "bind" ];
  #   };
  #
  # fileSystems."/swap" =
  #   { device = "/dev/disk/by-uuid/905b4626-9364-477c-bdb7-0275d520ce31";
  #     fsType = "btrfs";
  #     options = [ "subvol=swap" "noatime" ];
  #   };

  # swapDevices = [ { device = "/swap/swapfile"; } ];

  # services.create_ap = {
  #   enable = false;
  #   settings = {
  #     FREQ_BAND = 5;
  #     HT_CAPAB = "[HT20][HT40-][HT40+][SHORT-GI-20][SHORT-GI-40][TX-STBC][MAX-AMSDU-7935][DSSS_CCK-40][PSMP]";
  #     VHT_CAPAB = "[MAX-MPDU-11454][RXLDPC][SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1][MAX-A-MPDU-LEN-EXP0]";
  #     IEEE80211AC = true;
  #     IEEE80211N = true;
  #     GATEWAY = "192.18.5.1";
  #     PASSPHRASE = "asdfasdfasdf";
  #     INTERNET_IFACE = "wlp0s20f0u3";
  #     WIFI_IFACE = "wlp0s20f3";
  #     SSID = "hopstop";
  #   };
  # };

  system.stateVersion = "23.05";
}

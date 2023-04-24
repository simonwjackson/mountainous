{ pkgs, ... }:

{
  imports = [
    ./dell-9710
    ./sunshine.nix
    ./disks.nix
    ./networking
    ./screens.nix
    ../../modules/syncthing.nix
    ../../profiles/gui
    ../../profiles/audio.nix
    ../../profiles/workstation.nix
    ../../profiles/_common.nix
    ../../users/simonwjackson
  ];

  programs.steam = {
    enable = true;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "raiden";

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
      documents.devices = [ "kuro" "unzen" "ushiro" "raiden" ];
      code.devices = [ "unzen" "ushiro" "raiden" ];
    };
  };

  system.stateVersion = "23.05"; # Did you read the comment?
}

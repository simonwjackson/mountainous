{ pkgs, ... }: {
  imports = [
    ./dell-9710
    ./sunshine.nix
    ./disks.nix
    ./networking
    ../../profiles/audio.nix
    ../../profiles/_common.nix
  ];

  programs.steam = {
    enable = true;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "raiden";

  services.xserver.enable = true;

  # Enable the Plasma 5 Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;


  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  # Enable touchpad support (enabled default in most desktopManager).
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

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "simonwjackson";

  environment.systemPackages = [
    pkgs.sunshine
    pkgs.pkgs.cifs-utils
    pkgs.xfsprogs
    pkgs.fuse3 # for nofail option on mergerfs (fuse defaults to fuse2)
    pkgs.mergerfs
    pkgs.mergerfs-tools
  ];

  system.stateVersion = "23.05"; # Did you read the comment?
}

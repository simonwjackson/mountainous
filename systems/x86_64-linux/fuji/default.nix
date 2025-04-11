{pkgs, ...}: {
  # Basic system configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network configuration
  networking = {
    hostName = "nixos"; # Define your hostname
    networkmanager.enable = true;
  };

  # Time zone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Basic packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    ex
  ];

  # Enable SSH
  services.openssh.enable = true;

  # User configuration
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    initialPassword = "changeme";
  };

  # Enable flakes
  nix.settings.experimental-features = ["nix-command" "flakes"];

  mountainous.hyprland = {
    enable = true;
    autoLogin = true;
  };

  # Enable VM display auto-resizing for QEMU virtual machines
  mountainous.vm.enable = true;

  nix.settings = {
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  # This is required for NixOS
  system.stateVersion = "25.05";
}

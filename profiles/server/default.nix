# Thin server profile — imports + defaults, no mkEnableOption
{ config, lib, pkgs, ... }:

{
  # Nix settings
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [ "nix-command" "flakes" ];
  };

  # Security defaults
  security.sudo.wheelNeedsPassword = false;

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # Basic packages
  environment.systemPackages = with pkgs; [
    vim
    curl
    htop
    git
    jq
  ];

  # Allow unfree
  nixpkgs.config.allowUnfree = true;

  # Mosh
  programs.mosh.enable = true;
}

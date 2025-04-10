# Default home-manager configuration for all systems
{ config, pkgs, ... }:

{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "nixos";
  home.homeDirectory = "/home/nixos";

  # Basic shell configuration
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
    };
  };

  # Git configuration
  programs.git = {
    enable = true;
    userName = "NixOS User";
    userEmail = "user@example.com";
  };

  # Install some basic packages
  home.packages = with pkgs; [
    htop
    ripgrep
    fd
    jq
  ];

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  home.stateVersion = "23.11";
}

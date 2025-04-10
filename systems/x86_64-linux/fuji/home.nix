# System-specific home-manager configuration for fuji
{ config, pkgs, ... }:

{
  # Add system-specific configuration here
  # This will be merged with the default configuration

  # Additional packages specific to this system
  home.packages = with pkgs; [
    neovim
  ];

  # System-specific settings
  programs.git.extraConfig = {
    init.defaultBranch = "main";
  };
}

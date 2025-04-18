# Default home-manager configuration for all systems
{
  config,
  pkgs,
  ...
}: {
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.zsh.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "simonwjackson";
  home.homeDirectory = "/home/simonwjackson";

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

  # Environment variables
  home.sessionVariables = {
    # This is a hack to get around a bug in nixos-option
    # TODO: Remove this when nixos-option is fixed
    # INFO: https://github.com/NixOS/nixpkgs/issues/291051
    NIXOS_OZONE_WL = "1";

    # Allow non-free packages
    NIXPKGS_ALLOW_UNFREE=1;
    
    BROWSER = "firefox";
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  home.stateVersion = "24.11";
}

{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.mountainous.profiles.workspace;
in {
  options.mountainous.profiles.workspace = {
    enable = mkEnableOption "Whether to enable the workspace profile";
  };

  config = mkIf cfg.enable {
    mountainous = {
      sound.enable = true;
      performance.enable = true;
      hyprland.enable = true;
    };

    # Workspace packages
    environment.systemPackages = with pkgs; [
      git
      obsidian
      xdg-desktop-portal-gtk
      yazi
    ];
  };
}

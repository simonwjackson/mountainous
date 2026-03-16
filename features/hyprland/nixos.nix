{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.features.hyprland;
in {
  config = mkIf cfg.enable {
    programs.hyprland = {
      enable = mkDefault true;
      xwayland.enable = mkDefault true;
    };
  };
}

{
  lib,
  pkgs,
  inputs,
  system,
  target,
  format,
  virtual,
  systems,
  config,
  ...
}: let
  cfg = config.mountainous.hyprland;
in {
  options.mountainous.hyprland = {
    enable = lib.mkEnableOption "Whether to enable the hyprland desktop";

    autoLogin = lib.mkEnableOption "Whether to auto login to the hyprland desktop";
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      # package = inputs.hyprland.packages.${system}.hyprland;
    };

    environment.systemPackages = [
      pkgs.ddcutil
      pkgs.eww
    ];

    xdg.portal.enable = true;

    security.pam.services.hyprlock = {};

    services = {
      displayManager.sddm.wayland.enable = true;
      displayManager.sddm.enable = true;
      displayManager.defaultSession = lib.mkIf cfg.autoLogin "hyprland";
      displayManager.autoLogin = lib.mkIf cfg.autoLogin {
        enable = true;
        # user = config.mountainous.user.name;
        user = "nixos";
      };
    };

    environment.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
    };
  };
}
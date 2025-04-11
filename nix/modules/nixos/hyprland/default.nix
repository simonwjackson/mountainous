{
  lib,
  pkgs,
  inputs,
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
    # Add hyprland cache
    nix.settings = {
      substituters = ["https://hyprland.cachix.org"];
      trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
    };

    programs.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    };

    environment.systemPackages = [
      pkgs.ddcutil
      pkgs.eww
    ];

    # TODO: is this still needed? now that we have portalPackage..
    xdg.portal.enable = true;

    security.pam.services.hyprlock = {};

    services = {
      displayManager.sddm.wayland.enable = true;
      displayManager.sddm.enable = true;
      displayManager.defaultSession = lib.mkIf cfg.autoLogin "hyprland";
      displayManager.autoLogin = lib.mkIf cfg.autoLogin {
        enable = true;
        # user = config.mountainous.user.name;
        user = "simonwjackson";
      };
    };

    environment.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
    };
  };
}
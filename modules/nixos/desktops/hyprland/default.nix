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
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.desktops.hyprland;
in {
  imports = [./hyprlandControl.nix];
  options.mountainous.desktops.hyprland = {
    enable = lib.mkEnableOption "Whether to enable the hyprland desktop";

    autoLogin = lib.mkEnableOption "Whether to auto login to the hyprland desktop";
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${system}.hyprland;
    };

    environment.systemPackages = [
      pkgs.ddcutil
      pkgs.eww
      # HACK
      pkgs.slurp
      pkgs.pngquant
      pkgs.grim
      pkgs.jq
      pkgs.swappy
      pkgs.wl-clipboard
    ];

    xdg.portal = enabled;
    # programs.xwayland = enabled;

    services = {
      # xserver = {
      #   enable = true;
      # };

      displayManager.sddm.wayland = enabled;
      displayManager.sddm.enable = true;
      displayManager.defaultSession = lib.mkIf cfg.autoLogin "hyprland";
      displayManager.autoLogin = lib.mkIf cfg.autoLogin {
        enable = true;
        user = config.mountainous.user.name;
      };
    };

    environment.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
    };
  };
}

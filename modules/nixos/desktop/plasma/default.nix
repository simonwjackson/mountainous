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

  cfg = config.mountainous.desktop.plasma;
in {
  options.mountainous.desktop.plasma = {
    enable = lib.mkEnableOption "Whether to enable the plasma desktop";
  };

  config = lib.mkIf cfg.enable {
    xdg.portal = enabled;
    programs.xwayland = enabled;

    services = {
      xserver = {
        enable = true;
        desktopManager.plasma5 = enabled;
      };

      displayManager = {
        sddm = {
          enable = true;
          wayland.enable = true;
        };
        defaultSession = "plasmawayland";
        autoLogin = {
          enable = true;
          user = config.mountainous.user.name;
        };
      };
    };

    environment.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
    };
  };
}

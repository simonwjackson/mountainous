{
  config,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled;
  cfg = config.mountainous.desktops.plasma;
in {
  options.mountainous.desktops.plasma = {
    enable = lib.mkEnableOption "Whether to enable the plasma desktop";
    autoLogin = lib.mkEnableOption "Whether to auto login to the plasma desktop";
  };

  config = lib.mkIf cfg.enable {
    xdg.portal = enabled;
    programs.xwayland = enabled;

    services = {
      desktopManager.plasma6 = enabled;

      xserver = enabled;

      displayManager.sddm.wayland = enabled;
      displayManager.sddm.enable = true;
      displayManager.defaultSession = lib.mkIf cfg.autoLogin "plasma";
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

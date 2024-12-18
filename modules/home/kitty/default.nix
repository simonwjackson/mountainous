{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption;

  cfg = config.mountainous.kitty;
in {
  options.mountainous.kitty = {
    enable = mkEnableOption "Whether to enable kitty";
    shellIntegration = {
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      sessionVariables = {
        TERMINAL = "kitty";
      };
    };

    programs.kitty = {
      enable = true;
      extraConfig = builtins.readFile ./kitty.conf;
      themeFile = "Catppuccin-Frappe";
    };

    # xdg.systemDirs.data = ["/usr/share" "/var/lib/flatpak/exports/share" "$HOME/.local/share/flatpak/exports/share"];
    #
    # systemd.user = {
    #   sessionVariables = {
    #     CLUTTER_BACKEND = "wayland";
    #     GDK_BACKEND = "wayland,x11";
    #     QT_QPA_PLATFORM = "wayland;xcb";
    #     MOZ_ENABLE_WAYLAND = "1";
    #     _JAVA_AWT_WM_NONREPARENTING = "1";
    #     STEAM_EXTRA_COMPAT_TOOL_PATHS = "/home/simonwjackson/.local/share/Steam/compatibilitytools.d/SteamTinkerLaunch/";
    #   };
    # };
  };
}

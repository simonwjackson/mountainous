{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkDefault mkOption types;
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.profiles.workspace;
in {
  options.mountainous.profiles.workspace = {
    enable = mkEnableOption "Enable workspace profile";
    desktop = mkOption {
      type = types.bool;
      default = true;
      description = "Enable desktop environment";
    };
  };

  config = lib.mkIf cfg.enable {
    services.playerctld = enabled;

    boot = {
      kernelParams = [
        "quiet" # Reduce boot messages
        "splash" # Enable splash screen
      ];

      plymouth = {
        enable = true;
        theme = "spinner";
        logo = ../../../../public/mountainous-tiny.png;
      };
    };

    console = {
      earlySetup = true;
    };

    programs.icho = {
      enable = lib.mkDefault true;
      environment = {
        NOTES_DIR = mkDefault "/snowscape/notes";
      };
      environmentFiles = [
        config.age.secrets."user-simonwjackson-anthropic".path
        config.age.secrets."deepseek-api-key".path
      ];
    };

    # programs.webapps = lib.mkIf cfg.desktop.enable {
    #   "photopea" = {
    #     windowState = "normal";
    #     name = "photopea";
    #     url = "https://photopea.com";
    #   };
    #
    #   "youtube" = {
    #     name = "youtube";
    #     url = "https://youtube.com";
    #   };
    # };

    mountainous = {
      desktops = lib.mkIf cfg.desktop {
        hyprctl-api = enabled;
        hyprland = {
          enable = true;
          autoLogin = true;
        };
      };
    };
  };
}

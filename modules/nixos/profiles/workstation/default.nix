{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkDefault;
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.profiles.workstation;
in {
  options.mountainous.profiles.workstation = {
    enable = mkEnableOption "Enable workstation profile";
  };

  config = lib.mkIf cfg.enable {
    services.playerctld = enabled;

    boot = {
      earlyVconsoleSetup = true;
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

    # programs.webapps = {
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
      desktops = {
        hyprctl-api = enabled;
        hyprland = {
          enable = true;
          autoLogin = true;
        };
      };
      networking = {
        tailscale = {
          enable = true;
          interfaceName = "tailscale";
        };
        tailscaled.enable = lib.mkForce false;
      };
      performance = enabled;
    };
  };
}

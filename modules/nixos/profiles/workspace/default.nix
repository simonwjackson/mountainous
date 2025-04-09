{
  config,
  lib,
  pkgs,
  inputs,
  system,
  ...
}: let
  inherit (lib) mkEnableOption mkDefault mkOption types;
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.profiles.workspace;

  icho = pkgs.symlinkJoin {
    name = "icho";
    paths = [inputs.icho.packages.${system}.default];
    buildInputs = [pkgs.makeWrapper];
    postBuild = let
      envScript = ''
        source ${config.age.secrets."user-simonwjackson-anthropic".path}
        source ${config.age.secrets."deepseek-api-key".path}
      '';
    in ''
      for bin in $out/bin/*; do
        wrapProgram $bin \
          --run ${pkgs.lib.escapeShellArg envScript}
      done
    '';
  };
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

    environment.systemPackages = [
      icho
    ];

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

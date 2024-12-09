{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.services.watch;
in {
  options.mountainous.services.watch = {
    enable = mkEnableOption "Whether to enable";

    address = {
      host = mkOption {
        type = types.str;
        description = "Host address for the container network";
      };

      client = mkOption {
        type = types.str;
        description = "Client address for the container network";
      };
    };

    tailscale = {
      authFile = mkOption {
        type = types.path;
        description = "Path to the Tailscale auth key file";
        default = config.age.secrets."tailscale-ephemeral".path;
      };
    };

    paths = {
      music = mkOption {
        type = types.path;
        description = "Path to music albums directory";
      };

      videos = mkOption {
        type = types.path;
        description = "Path to videos directory";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    containers.watch = {
      hostAddress = cfg.address.host;
      localAddress = cfg.address.client;
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${cfg.tailscale.authFile}" = {
          hostPath = cfg.tailscale.authFile;
          isReadOnly = true;
        };
        "/snowscape/music/albums" = {
          hostPath = cfg.paths.music;
          isReadOnly = false;
        };
        "/snowscape/videos" = {
          hostPath = cfg.paths.videos;
          isReadOnly = false;
        };
      };

      config = {...}: {
        imports = [
          inputs.self.nixosModules."networking/tailscaled"
          inputs.self.nixosModules."_profiles/container"
        ];

        services.jellyfin = {
          enable = true;
          user = "media";
          group = "media";
        };

        systemd.services.jellyfin = {
          serviceConfig = {
            LimitNOFILE = 65535;
          };
        };

        mountainous = {
          profiles.container.enable = true;

          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = cfg.tailscale.authFile;
              serve = 8096;
            };
          };
        };

        system.stateVersion = "24.11";
      };
    };
  };
}

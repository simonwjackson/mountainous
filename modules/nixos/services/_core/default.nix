{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  inherit (lib.mountainous) enabled;

  protonAddress = "10.2.0.2/32";
  protonDns = "10.2.0.1";
  protonPort = 51820;

  cfg = config.mountainous.services.soulseek;
in {
  options.mountainous.services.soulseek = {
    enable = mkEnableOption "Whether to enable";

    tailscaleAuthFile = mkOption {
      type = types.path;
      description = "Path to the Tailscale authentication file";
      default = config.age.secrets."tailscale-ephemeral".path;
    };

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
  };

  config = lib.mkIf cfg.enable {
    containers.soulseek = let
      proton0SoulseekPrivateKeyFile = config.age.secrets."proton-0-soulseek".path;
      slskdEnvFile = config.age.secrets."slskd_env".path;
    in {
      hostAddress = cfg.address.host;
      localAddress = cfg.address.client;
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${cfg.tailscaleAuthFile}".hostPath = cfg.tailscaleAuthFile;
        "${slskdEnvFile}".hostPath = slskdEnvFile;
        "${proton0SoulseekPrivateKeyFile}".hostPath = proton0SoulseekPrivateKeyFile;
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules.wg-killswitch
          inputs.self.nixosModules."networking/tailscaled"
        ];

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          wg-killswitch = {
            enable = true;
            name = "protonvpn";
            address = protonAddress;
            dns = protonDns;
            gateway = cfg.address.host;
            privateKeyFile = proton0SoulseekPrivateKeyFile;
            publicKey = "jqu/dcZfEtote0IN1H4ZFneR8p4sZ7juna+eUndhRgs=";
            server = "89.187.175.132";
            port = protonPort;
          };

          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = cfg.tailscaleAuthFile;
              serve = 5030;
            };
          };
        };

        systemd.services.slskd = {
          serviceConfig = {
            UMask = "0002";
          };
        };

        services.slskd = {
          enable = true;
          user = "media";
          group = "media";
          environmentFile = slskdEnvFile;
          domain = null;
          settings.shares.directories = [];
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            home = "/var/lib/slskd";
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
            isNormalUser = false;
          };
        };
      };
    };
  };
}

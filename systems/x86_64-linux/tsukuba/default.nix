{
  inputs,
  modulesPath,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled disabled;
in {
  imports = [
    (import ./disko.nix {
      device = "/dev/vda";
    })
  ];

  facter.reportPath = ./facter.json;

  boot = {
    kernelModules = [
      "nvme"
      "ahci" # SATA
    ];
    loader = {
      grub = {
        enable = true;
      };
    };
  };

  mountainous = {
    boot = disabled;
    profiles = {
      base = enabled;
      laptop = disabled;
      workstation = disabled;
    };
    # TODO: encrypt generated syncthing keys
    syncthing = {
      enable = true;
    };
  };

  networking = {
    nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      externalInterface = "ens3";
    };

    firewall = {
      enable = true;
    };
  };

  environment.persistence."${config.mountainous.impermanence.persistPath}" = lib.mkIf config.mountainous.impermanence.enable {
    directories = [
      "/var/lib/nixos-containers/search"
    ];
  };

  containers = let
    tailscaleAuthFile = config.age.secrets."tailscale".path;
    tailscaleMagicDns = "hummingbird-lake.ts.net";

    hostAddress = "192.168.99.81";
  in {
    search = let
      searxEnvFile = config.age.secrets."searx-env".path;
    in {
      inherit hostAddress;

      localAddress = "192.168.99.82";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${searxEnvFile}" = {
          hostPath = searxEnvFile;
          isReadOnly = true;
        };
        "${tailscaleAuthFile}" = {
          hostPath = tailscaleAuthFile;
          isReadOnly = true;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.impermanence.nixosModules.impermanence
          inputs.self.nixosModules."networking/tailscale"
          inputs.self.nixosModules."impermanence"
        ];

        nixpkgs.config.allowUnfree = true;

        networking = {
          useHostResolvConf = false;
          enableIPv6 = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          networking = {
            tailscale = {
              enable = true;
              authKeyFile = tailscaleAuthFile;
              serve = 8888;
            };
          };
        };

        services.searx = {
          enable = true;
          redisCreateLocally = true;
          environmentFile = config.age.secrets."searx-env".path;
          settings.server = {
            bind_address = "0.0.0.0";
            port = 8888;
            secret_key = "@SEARX_SECRET_KEY@";
          };
        };
      };
    };
  };

  system.stateVersion = "24.11";
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types;
  cfg = config.mountainous.vault.immich;
  mediaCfg = config.mountainous.media;
in {
  options.mountainous.vault.immich = {
    enable = mkEnableOption "Immich photo and video backup server";

    user = mkOption {
      type = types.str;
      default = "immich";
      description = "User to run Immich as";
    };

    group = mkOption {
      type = types.str;
      default = "immich";
      description = "Group to run Immich as";
    };

    mediaLocation = mkOption {
      type = types.path;
      default = "/var/lib/immich";
      description = "Directory for Immich media storage (photos, videos, thumbnails)";
    };

    port = mkOption {
      type = types.port;
      default = 2283;
      description = "Port for Immich web interface";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall ports for Immich";
    };

    proxy = {
      enable = mkEnableOption "Tailscale proxy for Immich web UI";

      name = mkOption {
        type = types.str;
        default = "immich";
        description = "Tailscale hostname";
      };
    };

    machineLearning = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable machine learning features (face detection, object recognition)";
      };

      cuda = {
        enable = mkEnableOption "CUDA acceleration for machine learning (NVIDIA GPUs)";

        devices = mkOption {
          type = types.listOf types.str;
          default = ["/dev/nvidia0" "/dev/nvidiactl" "/dev/nvidia-uvm"];
          description = "NVIDIA device paths for CUDA acceleration";
        };
      };
    };

    hardware = {
      acceleration = {
        enable = mkEnableOption "Hardware acceleration for video transcoding";

        devices = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Device paths to pass through for hardware acceleration";
          example = ["/dev/dri/renderD128"];
        };
      };
    };

    secretsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a file containing secrets as environment variables.
        This file should contain sensitive values like database passwords.
      '';
    };

    settings = mkOption {
      type = types.nullOr types.attrs;
      default = null;
      description = ''
        Immich configuration as Nix attribute set.
        If null, configuration is done through the web UI.
        Setting this locks configuration to be read-only in the UI.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Additional environment variables for Immich";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Enable Immich service
      services.immich = {
        enable = true;
        host = "0.0.0.0";
        inherit (cfg) port openFirewall mediaLocation secretsFile settings environment;
        user = cfg.user;
        group = cfg.group;

        machine-learning.enable = cfg.machineLearning.enable;
      };

      # Hardware acceleration devices
      services.immich.accelerationDevices =
        mkIf cfg.hardware.acceleration.enable
        cfg.hardware.acceleration.devices;

      # Ensure immich user can access media paths if defined
      users.users.${cfg.user}.extraGroups =
        lib.optional (mediaCfg.group != cfg.group && mediaCfg.paths != {}) mediaCfg.group
        ++ lib.optionals cfg.hardware.acceleration.enable ["render" "video"];

      # Create media directory if it doesn't exist
      systemd.tmpfiles.rules = [
        "d ${cfg.mediaLocation} 0750 ${cfg.user} ${cfg.group} -"
      ];

      # Impermanence integration - persist Immich internal state (not media)
      environment.persistence."${config.mountainous.impermanence.persistPath}" =
        mkIf (config.mountainous.impermanence.enable or false)
        {
          directories = [
            {
              inherit (cfg) user group;
              directory = "/var/lib/immich";
              mode = "0750";
            }
          ];
        };
    }

    # Tailscale proxy for remote access
    (mkIf cfg.proxy.enable {
      mountainous.tsnet-proxy.services.immich = {
        hostname = cfg.proxy.name;
        protocol = "http";
        port = cfg.port;
      };
    })

    # CUDA acceleration for machine learning
    (mkIf (cfg.machineLearning.enable && cfg.machineLearning.cuda.enable) {
      # Override onnxruntime to build with CUDA support
      nixpkgs.overlays = [
        (final: prev: {
          onnxruntime = prev.onnxruntime.override {cudaSupport = true;};
        })
      ];

      # Configure ML service with CUDA library paths
      services.immich.machine-learning.environment = {
        LD_LIBRARY_PATH = lib.concatStringsSep ":" [
          "${pkgs.python312Packages.onnxruntime}/lib"
          "${pkgs.python312Packages.onnxruntime}/lib/python3.12/site-packages/onnxruntime/capi"
        ];
      };

      # Grant ML service access to NVIDIA devices
      systemd.services.immich-machine-learning.serviceConfig = {
        PrivateDevices = lib.mkForce false;
        DeviceAllow = cfg.machineLearning.cuda.devices;
      };

      # Add user to video group for GPU access
      users.users.${cfg.user}.extraGroups = ["video"];
    })
  ]);
}

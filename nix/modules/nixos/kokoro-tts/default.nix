{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types;
  cfg = config.mountainous.kokoro-tts;

  # Get the package with or without CUDA support
  kokoroPackage = pkgs.callPackage ../../../packages/kokoro-fastapi {
    cudaSupport = cfg.cuda;
  };
in {
  options.mountainous.kokoro-tts = {
    enable = mkEnableOption "Kokoro-FastAPI TTS server";

    port = mkOption {
      type = types.port;
      default = 8880;
      description = "Port to run Kokoro TTS API on";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Host to bind to";
    };

    cuda = mkOption {
      type = types.bool;
      default = false;
      description = "Enable CUDA/GPU acceleration";
    };

    cudaDevices = mkOption {
      type = types.listOf types.str;
      default = ["/dev/nvidia0" "/dev/nvidiactl" "/dev/nvidia-uvm"];
      description = "NVIDIA device paths for CUDA acceleration";
    };

    modelDir = mkOption {
      type = types.path;
      default = "/var/lib/kokoro-tts/models";
      description = "Directory for TTS models";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall port for Kokoro TTS";
    };

    user = mkOption {
      type = types.str;
      default = "kokoro-tts";
      description = "User to run Kokoro TTS as";
    };

    group = mkOption {
      type = types.str;
      default = "kokoro-tts";
      description = "Group to run Kokoro TTS as";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Create user and group
      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        description = "Kokoro TTS service user";
      };

      users.groups.${cfg.group} = {};

      # Firewall configuration
      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];

      # Create model directory
      systemd.tmpfiles.rules = [
        "d ${cfg.modelDir} 0750 ${cfg.user} ${cfg.group} -"
      ];

      # Main systemd service
      systemd.services.kokoro-tts = {
        description = "Kokoro-FastAPI TTS Server";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];

        environment = {
          PHONEMIZER_ESPEAK_PATH = "${pkgs.espeak-ng}/bin/espeak-ng";
          ESPEAK_DATA_PATH = "${pkgs.espeak-ng}/share/espeak-ng-data";
        };

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          ExecStart = "${kokoroPackage}/bin/kokoro-fastapi --host ${cfg.host} --port ${toString cfg.port}";
          Restart = "on-failure";
          RestartSec = "5s";

          # Security hardening
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [cfg.modelDir];

          # Standard output
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };
    }

    # CUDA acceleration configuration
    (mkIf cfg.cuda {
      # Add CUDA environment variables
      systemd.services.kokoro-tts.environment = {
        USE_GPU = "true";
        DEVICE = "cuda";
        LD_LIBRARY_PATH = lib.makeLibraryPath [
          pkgs.cudaPackages.cudatoolkit
        ];
      };

      # Grant access to NVIDIA devices
      systemd.services.kokoro-tts.serviceConfig = {
        PrivateDevices = lib.mkForce false;
        DeviceAllow = cfg.cudaDevices;
      };

      # Add user to video group for GPU access
      users.users.${cfg.user}.extraGroups = ["video"];
    })
  ]);
}

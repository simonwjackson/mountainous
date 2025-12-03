{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.openreader;
in {
  options.mountainous.openreader = {
    enable = mkEnableOption "OpenReader-WebUI ebook reader with TTS";

    port = mkOption {
      type = types.port;
      default = 3003;
      description = "Port to run OpenReader on";
    };

    hostname = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Hostname to bind OpenReader to";
    };

    ttsEndpoint = mkOption {
      type = types.str;
      default = "http://localhost:8880/v1";
      description = "Kokoro-FastAPI TTS endpoint URL (OpenAI-compatible endpoint)";
    };

    stateDir = mkOption {
      type = types.path;
      default = "/var/lib/openreader";
      description = "Directory for OpenReader state/documents";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall port for OpenReader";
    };

    user = mkOption {
      type = types.str;
      default = "openreader";
      description = "User account under which OpenReader runs";
    };

    group = mkOption {
      type = types.str;
      default = "openreader";
      description = "Group account under which OpenReader runs";
    };
  };

  config = mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.stateDir;
      description = "OpenReader service user";
    };

    users.groups.${cfg.group} = {};

    # Ensure state directory exists
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # systemd service
    systemd.services.openreader = {
      description = "OpenReader-WebUI ebook reader with TTS";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment = {
        NODE_ENV = "production";
        PORT = toString cfg.port;
        HOSTNAME = cfg.hostname;
        API_BASE = cfg.ttsEndpoint;
        DATA_DIR = cfg.stateDir;
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        ExecStart = "${pkgs.openreader-webui}/bin/openreader-webui";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [cfg.stateDir];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = false; # Node.js needs JIT
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        PrivateMounts = true;
      };
    };

    # Optional firewall rule
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [cfg.port];
    };
  };
}

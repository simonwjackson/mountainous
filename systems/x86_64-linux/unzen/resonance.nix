# resonance-service.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.resonance;
in {
  options.services.resonance = {
    enable = mkEnableOption "Resonance music server";

    package = mkOption {
      type = types.package;
      default = pkgs.resonance;
      defaultText = literalExpression "pkgs.resonance";
      description = "The Resonance package to use";
    };

    port = mkOption {
      type = types.port;
      default = 5000;
      description = "Port for the Resonance server to listen on";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/resonance";
      description = "Directory to store Resonance data";
    };

    user = mkOption {
      type = types.str;
      default = "resonance";
      description = "User account under which Resonance runs";
    };

    group = mkOption {
      type = types.str;
      default = "resonance";
      description = "Group under which Resonance runs";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to open the firewall for Resonance";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional command-line arguments to pass to Resonance";
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = {};

    systemd.services.resonance = {
      description = "Resonance Music Server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = concatStringsSep " " (
          ["${cfg.package}/bin/resonance"] ++ cfg.extraArgs
        );
        WorkingDirectory = cfg.dataDir;
        Restart = "always";
        RestartSec = "10";

        # # Hardening options
        # NoNewPrivileges = true;
        # ProtectSystem = "strict";
        # ProtectHome = true;
        # PrivateTmp = true;
        # PrivateDevices = true;
        # ProtectKernelTunables = true;
        # ProtectKernelModules = true;
        # ProtectControlGroups = true;
        # RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        # RestrictNamespaces = true;
        # LockPersonality = true;
        # MemoryDenyWriteExecute = true;
        # RestrictRealtime = true;
        # RestrictSUIDSGID = true;
        # RemoveIPC = true;
        #
        # # Allow network access
        # PrivateNetwork = false;

        # Ensure the data directory is writable
        ReadWritePaths = [cfg.dataDir];
      };
    };

    # networking.firewall = mkIf cfg.openFirewall {
    #   allowedTCPPorts = [cfg.port];
    # };
  };
}

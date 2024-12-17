{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (config.networking) hostName;
  inherit (lib) mkOption mkEnableOption mkIf optionalAttrs;
  inherit (lib.types) listOf bool str path int submodule;
  inherit (lib.mountainous) knownHostsBuilder;

  cfg = config.mountainous.networking.tailscale;
  impermanence = config.mountainous.impermanence;

  # Port configuration type
  portOptions = {...}: {
    options = {
      local = mkOption {
        type = int;
        description = "Local port to serve";
      };
      remote = mkOption {
        type = int;
        default = null;
        description = "Remote port to map to (defaults to local port if not specified)";
      };
      funnel = mkOption {
        type = bool;
        default = false;
        description = "Whether to expose this port via Tailscale Funnel";
      };
    };
  };

  # Generate systemd service for a port mapping
  makeServeService = portCfg: let
    local = toString portCfg.local;
    remote = toString (
      if portCfg.remote == null
      then portCfg.local
      else portCfg.remote
    );
    funnelFlag =
      if portCfg.funnel
      then " --funnel"
      else "";
  in {
    name = "tailscale-serve-from-${local}-to-${remote}";
    value = {
      description = "Tailscale serve for port ${local} -> ${remote}${lib.optionalString portCfg.funnel " (funneled)"}";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "tailscaled.service"];
      requires = ["tailscaled.service"];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve${funnelFlag} ${local} ${remote}";
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };
in {
  options.mountainous.networking.tailscale = {
    enable = lib.mkEnableOption "Enable Tailscale";

    interfaceName = mkOption {
      type = str;
      default = "tailscale0";
      description = ''
        The name of the Tailscale interface.
        This affects firewall rules and network configuration.
      '';
    };

    serve = mkOption {
      type = listOf (submodule portOptions);
      default = [];
      example = [
        {
          local = 443;
          funnel = true;
        }
        {
          local = 8443;
          remote = 443;
          funnel = true;
        }
      ];
      description = ''
        List of ports to serve via Tailscale.
        Each entry is an attribute set with:
          * local: Local port to serve
          * remote: Remote port to map to (optional, defaults to local port)
          * funnel: Whether to expose via Tailscale Funnel (optional, defaults to false)

        This option can be declared in multiple modules and the lists will be concatenated.
      '';
    };

    extraUpFlags = mkOption {
      type = listOf str;
      default = [];
      example = ["--accept-routes" "--shields-up"];
      description = ''
        Additional arguments to pass to 'tailscale up'.
        These flags are used when bringing up the Tailscale interface.
      '';
    };

    extraSetFlags = mkOption {
      type = listOf str;
      default = [];
      example = ["--auto-update"];
      description = ''
        Additional arguments to pass to 'tailscale set'.
        These flags are used for modifying Tailscale's settings.
      '';
    };

    extraDaemonFlags = mkOption {
      type = listOf str;
      default = [];
      example = ["--verbose=1"];
      description = ''
        Additional arguments to pass to the Tailscale daemon (tailscaled).
        These flags control the behavior of the daemon itself.
      '';
    };

    exitNode = mkOption {
      type = bool;
      default = false;
      description = ''
        Whether this node should act as an exit node for the Tailscale network.
        When enabled, other nodes in the network can route their traffic through this node.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPortRanges = [
        {
          from = 1;
          to = 65535;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 1;
          to = 65535;
        }
      ];

      allowPing = true;
      trustedInterfaces = lib.mkAfter [cfg.interfaceName];
      allowedUDPPorts = [config.services.tailscale.port];

      # Exit node iptables rules (when not using nftables)
      extraCommands = lib.mkIf (cfg.exitNode) ''
        iptables -A FORWARD -i ${cfg.interfaceName} -j ACCEPT
        iptables -A FORWARD -o ${cfg.interfaceName} -j ACCEPT
      '';
      extraStopCommands = lib.mkIf (cfg.exitNode) ''
        iptables -D FORWARD -i ${cfg.interfaceName} -j ACCEPT || true
        iptables -D FORWARD -o ${cfg.interfaceName} -j ACCEPT || true
      '';
    };

    services.tailscale = {
      enable = true;
      authKeyFile = config.age.secrets."tailscale".path;
      interfaceName = cfg.interfaceName;
      useRoutingFeatures =
        if cfg.exitNode
        then "both"
        else "client";
      extraUpFlags = cfg.extraUpFlags ++ lib.optional cfg.exitNode "--advertise-exit-node=true";
      extraSetFlags = cfg.extraSetFlags;
      extraDaemonFlags = cfg.extraDaemonFlags;
    };

    # Configure exit node if enabled
    boot.kernel.sysctl = mkIf cfg.exitNode {
      # Enable IP forwarding
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    # Generate systemd services for port forwarding
    systemd.services = lib.mkIf (cfg.serve != []) (
      builtins.listToAttrs (map makeServeService cfg.serve)
    );

    environment.persistence."${impermanence.persistPath}" = mkIf impermanence.enable {
      files = [
        "/var/lib/tailscale/tailscaled.state"
      ];
    };
  };
}

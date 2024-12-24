{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (config.networking) hostName;
  inherit (lib) mkOption mkEnableOption mkIf optionalAttrs;
  inherit (lib.types) listOf bool str path int submodule either nullOr;
  inherit (lib.mountainous) knownHostsBuilder;

  cfg = config.mountainous.networking.tailscale;
  impermanence = config.mountainous.impermanence;

  # Port configuration type
  portOptions = {...}: {
    options = {
      from = mkOption {
        type = int;
        description = "Local port to serve from";
      };
      to = mkOption {
        type = int;
        default = 443;
        description = "HTTPS port to serve to (defaults to 443)";
      };
    };
  };

  # Generate systemd service for a port mapping
  makeServeService = portCfg: {
    name = "tailscale-serve-${toString portCfg.from}";
    value = {
      description = "Tailscale serve for port ${toString portCfg.from}";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "tailscaled.service"];
      requires = ["tailscaled.service"];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve --https=${toString portCfg.to} ${toString portCfg.from}";
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };

  # Generate systemd service for a funnel mapping
  makeFunnelService = portCfg: {
    name = "tailscale-funnel-${toString portCfg.from}";
    value = {
      description = "Tailscale funnel for port ${toString portCfg.from}";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "tailscaled.service"];
      requires = ["tailscaled.service"];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.tailscale}/bin/tailscale funnel --https=${toString portCfg.to} ${toString portCfg.from}";
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
      type = nullOr (either int (either (submodule portOptions) (listOf (submodule portOptions))));
      default = null;
      example = [
        { from = 8080; }
        { from = 3000; to = 8443; }
      ];
      description = ''
        Port configurations to serve via Tailscale.
        Can be:
          - A single port number (will serve from this port to HTTPS 443)
          - A single port configuration
          - A list of port configurations
        Each port configuration should be an attribute set with:
          - from: Local port to serve from
          - to: HTTPS port to serve to (defaults to 443)
      '';
    };

    funnel = mkOption {
      type = nullOr (either int (either (submodule portOptions) (listOf (submodule portOptions))));
      default = null;
      example = [
        { from = 8080; }
        { from = 3000; to = 8443; }
      ];
      description = ''
        Port configurations to funnel via Tailscale.
        Can be:
          - A single port number (will funnel from this port to HTTPS 443)
          - A single port configuration
          - A list of port configurations
        Each port configuration should be an attribute set with:
          - from: Local port to funnel from
          - to: HTTPS port to funnel to (defaults to 443, must be 443, 8443, or 10000)
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

    authKeyFile = mkOption {
      type = lib.types.nullOr path;
      default = config.age.secrets."tailscale".path;
      description = ''
        Path to the file containing the Tailscale authentication key.
        Defaults to the age-encrypted tailscale secret.
        Set to null to disable automatic authentication.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.serve == null || (
          let 
            serveList = if builtins.isInt cfg.serve
              then [{ from = cfg.serve; to = 443; }]
              else if builtins.isList cfg.serve 
              then cfg.serve 
              else [cfg.serve];
            toPorts = map (x: x.to) serveList;
            uniqueToPorts = lib.unique toPorts;
          in
          lib.length toPorts == lib.length uniqueToPorts
        );
        message = "Tailscale serve configurations must have unique 'to' ports";
      }
      {
        assertion = cfg.funnel == null || (
          let 
            funnelList = if builtins.isInt cfg.funnel
              then [{ from = cfg.funnel; to = 443; }]
              else if builtins.isList cfg.funnel 
              then cfg.funnel 
              else [cfg.funnel];
            toPorts = map (x: x.to) funnelList;
            uniqueToPorts = lib.unique toPorts;
            validPorts = lib.all (x: builtins.elem x [443 8443 10000]) toPorts;
          in
          lib.length toPorts == lib.length uniqueToPorts && validPorts
        );
        message = "Tailscale funnel configurations must have unique 'to' ports and only use ports 443, 8443, or 10000";
      }
    ];

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
      authKeyFile = cfg.authKeyFile;
      interfaceName = cfg.interfaceName;
      useRoutingFeatures =
        if cfg.exitNode
        then "both"
        else "client";
      extraUpFlags = cfg.extraUpFlags ++ lib.optional cfg.exitNode "--advertise-exit-node=true";
      extraSetFlags = cfg.extraSetFlags;
      extraDaemonFlags = cfg.extraDaemonFlags;
    };

    boot.kernel.sysctl = mkIf cfg.exitNode {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    environment.persistence."${impermanence.persistPath}" = mkIf impermanence.enable {
      directories = [
        "/var/lib/tailscale"
      ];
    };

    # HACK: Containers have issue with this for some reason
    systemd.services =
      {
        tailscaled-autoconnect.enable = cfg.authKeyFile != null && !config.boot.isContainer;
      }
      // (if cfg.serve != null 
          then lib.listToAttrs (map makeServeService (
            if builtins.isInt cfg.serve 
            then [{ from = cfg.serve; to = 443; }]
            else if builtins.isList cfg.serve 
            then cfg.serve 
            else [cfg.serve]
          ))
          else {})
      // (if cfg.funnel != null 
          then lib.listToAttrs (map makeFunnelService (
            if builtins.isInt cfg.funnel 
            then [{ from = cfg.funnel; to = 443; }]
            else if builtins.isList cfg.funnel 
            then cfg.funnel 
            else [cfg.funnel]
          ))
          else {});

    # Replace the default tailscaled-autoconnect with our custom implementation
    # systemd.services.tailscaled-autoconnect-container = mkIf (cfg.authKeyFile != null && config.boot.isContainer) {
    #   description = "Automatic connection to Tailscale network for containers";
    #
    #   after = ["network-online.target" "tailscaled.service"];
    #   wants = ["network-online.target"];
    #   requires = ["tailscaled.service"];
    #   wantedBy = ["multi-user.target"];
    #
    #   serviceConfig = {
    #     Type = "oneshot";
    #     RemainAfterExit = true;
    #     Restart = "on-failure";
    #     RestartSec = "5s";
    #     TimeoutStartSec = "60s";
    #
    #     ExecStart = let
    #       statusCommand = "${lib.getExe pkgs.tailscale} status --json --peers=false | ${lib.getExe pkgs.jq} -r '.BackendState'";
    #     in
    #       pkgs.writeShellScript "tailscale-autoconnect" ''
    #         # Wait for tailscaled to be ready
    #         for i in $(seq 1 13); do
    #           if ${lib.getExe pkgs.tailscale} status >/dev/null 2>&1; then
    #             break
    #           fi
    #           echo "Waiting for tailscaled to be ready... ($i/12)"
    #           sleep 5
    #         done
    #
    #         # Check current login state
    #         status="$(${statusCommand})"
    #
    #         # Authenticate if needed
    #         if [[ "$status" == "NeedsLogin" || "$status" == "NeedsMachineAuth" || "$status" == "NoState" ]]; then
    #           ${lib.getExe pkgs.tailscale} up --auth-key "$(cat ${cfg.authKeyFile})"
    #         fi
    #       '';
    #   };
    # };

    # Add this section to create the serve services
  };
}

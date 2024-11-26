{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.mountainous.wg-killswitch;
in {
  options.mountainous.wg-killswitch = {
    enable = mkEnableOption "FastestVPN container service";

    name = mkOption {
      type = types.strMatching "[a-zA-Z0-9_-]+";
      description = ''
        Name of the VPN interface. Must contain only alphanumeric characters,
        underscores, and hyphens.
      '';
      example = "fastestvpn";
    };

    address = mkOption {
      type = types.str;
      description = "Local IP address for the VPN interface";
      example = "172.16.10.78";
    };

    dns = mkOption {
      type = types.str;
      description = "DNS server for the VPN connection";
      example = "10.8.8.8";
    };

    gateway = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Gateway address for the container";
    };

    privateKeyFile = mkOption {
      type = types.str;
      description = "Private Key File";
    };

    publicKey = mkOption {
      type = types.str;
      description = "Public Key";
    };

    server = mkOption {
      type = types.str;
      description = "WireGuard server hostname or IP address";
      example = "vpn.example.com";
    };

    port = mkOption {
      type = types.port;
      description = "WireGuard server port";
      example = 51820;
    };

    allowedIPs = mkOption {
      type = types.listOf types.str;
      default = ["0.0.0.0/0"];
      description = ''
        List of IP (v4 or v6) ranges that are allowed through the VPN tunnel.
        Default routes all traffic through VPN.
      '';
      example = ["10.0.0.0/8" "192.168.0.0/16"];
    };

    killswitch = mkOption {
      type = types.bool;
      default = true;
      description = "Enable killswitch functionality for VPN connection";
    };
  };

  config = mkIf cfg.enable {
    # Add assertions for interface name validation
    assertions = [
      {
        assertion = builtins.match "[a-zA-Z0-9_-]+" cfg.name != null;
        message = "name '${cfg.name}' must contain only alphanumeric characters, underscores, and hyphens";
      }
    ];

    environment.systemPackages = with pkgs; [
      iproute2
      wireguard-tools
    ];

    networking = {
      firewall = {
        enable = true;
        allowPing = true;
        allowedUDPPorts = [
          cfg.port
          41641 # Tailscale port
        ];
      };

      wg-quick.interfaces = {
        "${cfg.name}" =
          {
            privateKeyFile = cfg.privateKeyFile;
            address = [cfg.address];
            dns = [cfg.dns];

            peers = [
              {
                publicKey = cfg.publicKey;
                allowedIPs = cfg.allowedIPs;
                endpoint = "${cfg.server}:${toString cfg.port}";
              }
            ];
          }
          // (mkIf cfg.killswitch {
            preUp = ''
              ip route del default || true
              ip route add default via ${cfg.gateway}
              ip route del ${cfg.server} || true
              ip route add ${cfg.server} via ${cfg.gateway}
            '';

            postUp = ''
              resolvectl dns ${cfg.name} ${cfg.dns}
              resolvectl domain ${cfg.name} "~."
              resolvectl default-route ${cfg.name} true
            '';

            preDown = ''
              ip route del default || true
              ip route del ${cfg.server} || true
              resolvectl revert ${cfg.name}
            '';
          });
      };
    };

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
    };

    systemd.services."wg-quick-${cfg.name}" = {
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
    };
  };
}

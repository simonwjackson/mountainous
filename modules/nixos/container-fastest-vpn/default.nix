{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.mountainous.container-fastest-vpn;
in {
  options.mountainous.container-fastest-vpn = {
    enable = mkEnableOption "FastestVPN container service";

    gateway = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Gateway address for the container";
    };

    privateKeyFile = mkOption {
      type = types.str;
      description = "WireGuard private key for FastestVPN";
    };

    publicKey = mkOption {
      type = types.str;
      description = "WireGuard public key for FastestVPN peer";
    };

    endpoint = mkOption {
      type = types.str;
      description = "FastestVPN WireGuard endpoint (format: host:port)";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      iproute2
      wireguard-tools
    ];

    networking = let
      localAddress = "172.16.10.78";
      dns = "10.8.8.8";
    in {
      firewall = {
        enable = true;
        allowPing = true;
        allowedUDPPorts = [
          51820 # WireGuard port
          41641 # Tailscale port
        ];
      };

      wg-quick.interfaces = {
        fastestvpn = {
          privateKeyFile = cfg.privateKeyFile;
          address = [localAddress];
          dns = [dns];

          peers = [
            {
              publicKey = cfg.publicKey;
              allowedIPs = ["0.0.0.0/0"];
              endpoint = cfg.endpoint;
            }
          ];

          preUp = ''
            ip route del default || true
            ip route add default via ${cfg.gateway}
            ip route del ${builtins.head (lib.splitString ":" cfg.endpoint)} || true
            ip route add ${builtins.head (lib.splitString ":" cfg.endpoint)} via ${cfg.gateway}
          '';

          postUp = ''
            resolvectl dns fastestvpn ${dns}
            resolvectl domain fastestvpn "~."
            resolvectl default-route fastestvpn true
          '';

          preDown = ''
            ip route del default || true
            ip route del ${cfg.endpoint} || true
            resolvectl revert fastestvpn
          '';
        };
      };
    };

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
    };

    systemd.services."wg-quick-fastestvpn" = {
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
    };
  };
}

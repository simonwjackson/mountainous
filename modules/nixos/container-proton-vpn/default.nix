{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.mountainous.container-proton-vpn;
in {
  options.mountainous.container-proton-vpn = {
    enable = mkEnableOption "ProtonVPN container service";

    gateway = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Gateway address for the container";
    };

    privateKeyFile = mkOption {
      type = types.str;
      description = "WireGuard private key for ProtonVPN";
    };

    publicKey = mkOption {
      type = types.str;
      description = "WireGuard public key for ProtonVPN peer";
    };

    endpoint = mkOption {
      type = types.str;
      description = "ProtonVPN WireGuard endpoint (format: host:port)";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      iproute2
      wireguard-tools
    ];

    networking = let
      server = "10.2.0.1";
    in {
      useHostResolvConf = false;
      nameservers = [server];

      interfaces.protonvpn = {
        ipv4.routes = [
          {
            address = "0.0.0.0";
            prefixLength = 1;
            via = server;
          }
        ];
      };

      firewall = {
        enable = true;
        allowPing = true;
        allowedUDPPorts = [
          51820 # WireGuard port
          41641 # Tailscale port
        ];
      };

      wg-quick.interfaces.protonvpn = {
        address = ["10.2.0.2/32"];
        dns = [server];
        privateKeyFile = cfg.privateKeyFile;

        preUp = ''
          ip route del default || true
          ip route add default via ${cfg.gateway}
          ip route del ${builtins.head (lib.splitString ":" cfg.endpoint)} || true
          ip route add ${builtins.head (lib.splitString ":" cfg.endpoint)} via ${cfg.gateway}
        '';

        preDown = ''
          ip route del default || true
          ip route del ${cfg.endpoint} || true
        '';

        peers = [
          {
            publicKey = cfg.publicKey;
            allowedIPs = ["0.0.0.0/0"];
            endpoint = cfg.endpoint;
            persistentKeepalive = 25;
          }
        ];
      };
    };

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
    };

    systemd.services.wg-quick-protonvpn.wantedBy = ["multi-user.target"];
  };
}

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
      curl
      wget
      iproute2
      wireguard-tools
    ];

    networking = {
      defaultGateway = cfg.gateway;
      useHostResolvConf = false;
      nameservers = ["10.2.0.1"];

      firewall = {
        enable = true;
        allowPing = true;
        allowedUDPPorts = [51820];
      };

      wg-quick.interfaces.protonvpn = {
        address = ["10.2.0.2/32"];
        dns = ["10.2.0.1"];
        privateKeyFile = cfg.privateKeyFile;

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

{ config, lib, ... }: {
  services.zerotierone.enable = true;
  services.zerotierone.joinNetworks = [ "abfd31bd47735e14" ]; # ZT NETWORK ID

  networking.firewall = {
    # always allow traffic from your Tailscale network
    trustedInterfaces = lib.mkAfter [ "ztc25efy2t" ];

    # allow the ZeroTeir UDP port through the firewall
    allowedUDPPorts = lib.mkAfter [ config.services.zerotierone.port ];
  };
}

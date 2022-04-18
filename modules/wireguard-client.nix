{ config, pkgs, ... }:

{
  networking.wireguard.interfaces = {
    mtn = {
      listenPort = 51820;

      peers = [
        # rakku
        {
          publicKey = "z5ymEx3zp7cEt8KkE7nO3TsqWJBOc3CycmwB171WYXU=";
          allowedIPs = [
            "192.18.1.0/24"
            "192.18.2.0/24"
          ];
          endpoint = "45.20.193.255:56789";
          persistentKeepalive = 25;
        }
      ];
    };
  };
}

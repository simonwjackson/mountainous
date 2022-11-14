{ config, pkgs, ... }:

{
  networking.wireguard.interfaces = {
    # mtn = {
    #   listenPort = 51820;

    #   peers = [
    #     {
    #       publicKey = builtins.getEnv "WIREGUARD_RAKKU_PUBLIC";
    #       allowedIPs = [
    #         "192.18.1.0/24"
    #         "192.18.2.0/24"
    #       ];

    #       endpoint = builtins.getEnv "WIREGUARD_RAKKU_ENDPOINT";
    #       persistentKeepalive = 25;
    #     }
    #   ];
    # };
  };
}

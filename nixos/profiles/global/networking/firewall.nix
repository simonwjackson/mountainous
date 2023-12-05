{config, ...}: let
  allowedMacAddresses = [
    "AC:74:B1:8A:DB:EE" # zao
    "D4:D8:53:90:2B:6C" # fiji
    "DC:F0:90:55:42:FD" # usu
  ];
in {
  networking.firewall = {
    enable = false;
    allowPing = true;

    extraCommands = ''
      ${builtins.concatStringsSep "\n" (map (mac: "iptables -I INPUT -m mac --mac-source ${mac} -j ACCEPT") allowedMacAddresses)}
    '';

    allowedTCPPorts = [
      # DNS
      53
    ];

    allowedUDPPorts = [
      # DHCP
      67
      68

      # DNS
      53

      # NTP
      123
    ];
  };
}

{ config, ... }:

{
  networking.firewall = {
    enable = true;
    allowPing = true;

    extraCommands = ''
      iptables -I INPUT -p all -s 192.168.166.0/24 -j ACCEPT
    '';

    allowedTCPPorts = [
      ## DNS
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

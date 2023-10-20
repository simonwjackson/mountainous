{ config, ... }:

{
  networking.firewall = {
    enable = true;
    allowPing = true;

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

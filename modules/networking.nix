{ config, pkgs, ... }:
{
  services.avahi.enable = true;
  services.avahi.wideArea = false;

  programs.mosh.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Easiest to use and most distros use this by default.
  networking.networkmanager.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
}

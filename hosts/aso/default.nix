{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware.nix
    ../../profiles/server
  ];

  home-manager.users.simonwjackson = import ../../home/simonwjackson;

  networking.hostName = "aso";
  time.timeZone = "America/Denver";

  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel"];
  };

  # WSL2: netfilter not fully supported
  mountainous.tailscale.extraUpFlags = ["--netfilter-mode=off"];

  networking.firewall = {
    enable = true;
    trustedInterfaces = ["tailscale0"];
    allowedUDPPorts = [config.services.tailscale.port];
  };

  # MagicDNS
  networking.nameservers = ["100.100.100.100" "1.1.1.1"];
  networking.search = ["hummingbird-lake.ts.net"];

  # Port 22 is taken by Windows SSH in mirrored networking mode
  services.openssh.ports = lib.mkForce [8080];

  system.stateVersion = "24.11";
}

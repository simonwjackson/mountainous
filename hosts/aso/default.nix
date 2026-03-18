{
  config,
  lib,
  ...
}: {
  imports = [
    ./hardware.nix
  ];

  networking.hostName = "aso";
  mountainous.presets.core.enable = true;
  mountainous.presets.server.enable = true;
  time.timeZone = "America/Denver";

  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "video"];
  };

  # WSL2: netfilter not fully supported
  mountainous.features.tailscale.extraUpFlags = ["--netfilter-mode=off"];

  networking.firewall = {
    enable = true;
    trustedInterfaces = ["tailscale0"];
    allowedUDPPorts = [config.services.tailscale.port];
  };

  networking.extraHosts = lib.mkForce ''
    10.101.0.4 amazesql01.database.windows.net
  '';

  # Port 22 is taken by Windows SSH in mirrored networking mode
  services.openssh.ports = lib.mkForce [8080];

  system.stateVersion = "24.11";
}

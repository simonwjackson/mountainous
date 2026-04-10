{
  config,
  lib,
  ...
}: {
  imports = [
    ./hardware.nix
  ];

  networking.hostName = "aso";
  time.timeZone = "America/Denver";

  mountainous = {
    presets = {
      core.enable = true;
      server.enable = true;
    };

    features = {
      # ── Networking ───────────────────────────────────────────────────
      tailscale.extraUpFlags = ["--netfilter-mode=off"];
    };
  };

  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "video"];
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = ["tailscale0"];
    allowedUDPPorts = [config.services.tailscale.port];
  };

  networking.extraHosts = lib.mkForce ''
    10.101.0.4  amazesql01.database.windows.net
    10.100.0.10 amazeportalsql.database.windows.net
  '';

  # Port 22 is taken by Windows SSH in mirrored networking mode
  services.openssh.ports = lib.mkForce [8080];

  system.stateVersion = "24.11";
}

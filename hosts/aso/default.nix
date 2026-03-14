{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware.nix
    ../../modules/server
  ];

  home-manager.users.simonwjackson = import ../../home/simonwjackson;

  networking.hostName = "aso";
  time.timeZone = "America/Denver";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "video"];
  };

  nixpkgs.config.allowUnfree = true;

  nix = {
    package = pkgs.nixVersions.latest;
    optimise.automatic = true;
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "@wheel" "simonwjackson"];
      trusted-substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://simonwjackson.cachix.org"
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "simonwjackson.cachix.org-1:MtG0AE8J6bjFO/wD04X5h8MlQh7Sbee8KAJrAsPJydI="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
      auto-optimise-store = true;
    };
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

  networking.extraHosts = lib.mkForce ''
    10.101.0.4 amazesql01.database.windows.net
  '';

  # Port 22 is taken by Windows SSH in mirrored networking mode
  services.openssh.ports = lib.mkForce [8080];

  system.stateVersion = "24.11";
}

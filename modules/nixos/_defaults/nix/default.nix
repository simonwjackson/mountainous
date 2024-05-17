{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: {
  config = {
    # Allow unfree packages
    nix = {
      package = pkgs.nixVersions.latest;
      # This will add each flake input as a registry
      # To make nix3 commands consistent with your flake
      registry = lib.mapAttrs (_: value: {flake = value;}) inputs;

      # This will additionally add your inputs to the system's legacy channels
      # Making legacy nix commands consistent as well, awesome!
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

      optimise.automatic = true;
      settings = {
        flake-registry = ""; # Disable global flake registry
        warn-dirty = false;
        # Enable flakes
        experimental-features = ["nix-command" "flakes"];
        # Add cachix binary cache
        substituters = [
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
          "https://simonwjackson.cachix.org"
        ];
        trusted-users = ["root" "@wheel" "simonwjackson" "admin"];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "simonwjackson.cachix.org-1:MtG0AE8J6bjFO/wD04X5h8MlQh7Sbee8KAJrAsPJydI="
        ];
        auto-optimise-store = true;
      };

      distributedBuilds = true;
      extraOptions = ''
        builders-use-substitutes = true
        !include ${config.age.secrets."user-simonwjackson-github-token-nix".path};
      '';
    };
  };
}

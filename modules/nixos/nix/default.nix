{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: {
  config = {
    nixpkgs = {
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "python-2.7.18.6"
        ];
      };
    };

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
        trusted-substituters = [
          "https://nix-gaming.cachix.org"
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
          "https://simonwjackson.cachix.org"
          "https://hyprland.cachix.org"
        ];
        trusted-users = ["root" "@wheel" "simonwjackson" "admin"];
        trusted-public-keys = [
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "simonwjackson.cachix.org-1:MtG0AE8J6bjFO/wD04X5h8MlQh7Sbee8KAJrAsPJydI="
          "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
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

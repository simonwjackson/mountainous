{
  config,
  inputs,
  lib,
  rootPath,
  ...
}: {
  age.secrets."user-simonwjackson-github-token-nix".file = rootPath + /secrets/user-simonwjackson-github-token-nix.age;

  nix = {
    optimise.automatic = true;
    settings = {
      trusted-users = ["root" "@wheel" "simonwjackson"];
      auto-optimise-store = lib.mkDefault true;
      experimental-features = ["nix-command" "flakes" "repl-flake"];
      warn-dirty = false;
      flake-registry = ""; # Disable global flake registry
      # substituters = ["https://nix-gaming.cachix.org"];
      # trusted-public-keys = ["nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="];
    };
    # gc = {
    #   automatic = true;
    #   dates = "weekly";
    #   # Keep the last 3 generations
    #   options = "--delete-older-than +3";
    # };

    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: {flake = value;}) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    buildMachines = [
      # {
      #   hostName = "zao";
      #   sshUser = "simonwjackson";
      #   system = "x86_64-linux";
      #   protocol = "ssh-ng";
      #   maxJobs = 12;
      #   speedFactor = 10;
      #   supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      #   mandatoryFeatures = [];
      # }
      # {
      #   hostName = "unzen";
      #   sshUser = "simonwjackson";
      #   system = "x86_64-linux";
      #   protocol = "ssh-ng";
      #   maxJobs = 6;
      #   speedFactor = 9;
      #   supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      #   mandatoryFeatures = [];
      # }
      # {
      #   hostName = "kita";
      #   system = "x86_64-linux";
      #   maxJobs = 0;
      # }
    ];

    distributedBuilds = true;

    # optional, useful when the builder has a faster internet connection than yours
    extraOptions = ''
      builders-use-substitutes = true
      !include ${config.age.secrets."user-simonwjackson-github-token-nix".path};
    '';
  };
}

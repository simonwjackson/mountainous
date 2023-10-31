{
  config,
  inputs,
  lib,
  ...
}: {
  nix = {
    settings = {
      trusted-users = ["root" "@wheel"];
      auto-optimise-store = lib.mkDefault true;
      experimental-features = ["nix-command" "flakes" "repl-flake"];
      warn-dirty = false;
      flake-registry = ""; # Disable global flake registry
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
      #   # systems = ["x86_64-linux" "aarch64-linux"];
      #   maxJobs = 4;
      #   speedFactor = 10;
      #   supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      #   mandatoryFeatures = [];
      # }
      {
        hostName = "unzen";
        sshUser = "simonwjackson";
        system = "x86_64-linux";
        protocol = "ssh-ng";
        maxJobs = 4;
        speedFactor = 9;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
        mandatoryFeatures = [];
      }
      {
        hostName = "fiji";
        sshUser = "simonwjackson";
        system = "x86_64-linux";
        protocol = "ssh-ng";
        maxJobs = 14;
        speedFactor = 8;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
        mandatoryFeatures = [];
      }
      {
        hostName = "yabashi";
        sshUser = "simonwjackson";
        system = "x86_64-linux";
        protocol = "ssh-ng";
        maxJobs = 1;
        speedFactor = 2;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
        mandatoryFeatures = [];
      }
      {
        hostName = "rakku";
        sshUser = "simonwjackson";
        system = "x86_64-linux";
        protocol = "ssh-ng";
        maxJobs = 1;
        speedFactor = 1;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
        mandatoryFeatures = [];
      }
    ];

    distributedBuilds = false;

    # optional, useful when the builder has a faster internet connection than yours
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };
}

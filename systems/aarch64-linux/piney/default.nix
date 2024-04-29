{
  lib,
  pkgs,
  inputs,
  system,
  target,
  format,
  virtual,
  systems,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  programs.myNeovim = {
    enable = true;
  };

  mountainous.networking.tailscaled.isMobileNixos = true;

  # nixpkgs.config.allowUnfree = true;
  nix = {
    optimise.automatic = true;
    settings = {
      trusted-users = ["root" "@wheel" "simonwjackson"];
      auto-optimise-store = lib.mkDefault true;
      experimental-features = ["nix-command" "flakes"];
      warn-dirty = false;
      flake-registry = ""; # Disable global flake registry
    };

    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    # registry = lib.mapAttrs (_: value: {flake = value;}) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    # nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    buildMachines = [
      # {
      #   hostName = "unzen";
      #   sshUser = "simonwjackson";
      #   systems = ["x86_64-linux" "aarch64-linux"];
      #   protocol = "ssh-ng";
      #   maxJobs = 6;
      #   speedFactor = 9;
      #   supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      #   mandatoryFeatures = [];
      # }
    ];

    distributedBuilds = true;

    # optional, useful when the builder has a faster internet connection than yours
    # extraOptions = ''
    #   builders-use-substitutes = true
    # '';
  };

  programs.mosh.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
    };
  };
  networking.hostName = "piney";

  #
  # Opinionated defaults
  #

  # Use Network Manager
  networking.wireless.enable = false;
  networking.networkmanager.enable = true;

  # Use PulseAudio
  hardware.pulseaudio.enable = true;

  # Enable Bluetooth
  hardware.bluetooth.enable = true;

  # Bluetooth audio
  hardware.pulseaudio.package = pkgs.pulseaudioFull;

  # Enable power management options
  powerManagement.enable = true;

  # It's recommended to keep enabled on these constrained devices
  zramSwap.enable = true;

  # Auto-login for phosh
  services.xserver.desktopManager.phosh = {
    user = "simonwjackson";
  };

  #
  # User configuration
  #

  users.users."simonwjackson" = {
    isNormalUser = true;
    description = "Simon W. Jackson";
    hashedPassword = "$6$HrsjijTxzxcw3Kw4$9qLus4MLJAhOFsYheWEYI1Ky4iOJpmLgJkQoN.Gr0Wvxaq5mFf/gosOEHL3mLmE0E3LEVag2qeVmCAbgv6boK0";
    packages = with pkgs; [
      firefox
      obsidian
      tmux
      git
    ];
    extraGroups = [
      "dialout"
      "feedbackd"
      "networkmanager"
      "video"
      "wheel"
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}

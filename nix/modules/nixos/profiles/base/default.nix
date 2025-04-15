# This file (and the global directory) holds config that i use on all hosts
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (lib) mkIf mkDefault mkEnableOption;
in {
  options.mountainous.profiles.base = {
    enable = mkEnableOption "Whether to enable the base profile.";
  };

  config = lib.mkIf config.mountainous.profiles.base.enable {
    ###################
    # Mountainous
    ###################

    mountainous = {
      user = {
        enable = mkDefault true;
        name = mkDefault "simonwjackson";
        # hashedPasswordFile = mkDefault config.age.secrets."user-simonwjackson".path;
        # authorizedKeys = let
        #   keysDir = ../../../../../keys/users;
        #   isPublicKey = name: type: type == "regular" && lib.hasSuffix ".pub" name;
        #   pubKeyFiles = lib.filterAttrs isPublicKey (builtins.readDir keysDir);
        #   keys = lib.mapAttrsToList (name: _: builtins.readFile (keysDir + "/${name}")) pubKeyFiles;
        # in
        #   keys;
      };
    };

    ###################
    # Misc
    ###################

    users = {
      groups.media = {
        gid = lib.mkForce 333;
      };

      users.media = {
        homeMode = "770";
        group = "media";
        uid = lib.mkForce 333;
        isNormalUser = false;
      };
    };

    # services.sunshine = {
    #   openFirewall = lib.mkDefault true;
    #   capSysAdmin = lib.mkDefault true;
    #   settings = {
    #     log_path = lib.mkDefault "/tmp/sunshine.log";
    #     key_rightalt_to_key_win = lib.mkDefault "enabled";
    #   };
    #   autoStart = lib.mkDefault false;
    # };

    # services.udev.extraRules = ''
    #   KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    #   KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
    # '';

    # environment.pathsToLink = ["/share/zsh"];

    # TODO: Move to (desktop?) profile
    environment.variables.BROWSER = "firefox";

    # Enable TTY mouse
    services.gpm.enable = true;

    # This is a hack to get around a bug in nixos-option
    # TODO: Remove this when nixos-option is fixed
    # INFO: https://github.com/NixOS/nixpkgs/issues/291051
    environment.etc."NIXOS_OZONE_WL".text = "1";

    hardware = {
      # This means we can use firmware that is not redistributable
      enableRedistributableFirmware = true;
      enableAllFirmware = true;
    };

    # VM-specific configuration that only applies when building a VM
    virtualisation.vmVariant = {
      # These settings only apply when building with nixos-rebuild build-vm
      virtualisation = {
        memorySize = 4096; # Example: Set VM memory to 4GB
        cores = 4; # Example: Set VM cores

        qemu.options = [
          # Force auto-resize to be enabled
          "-device virtio-gpu-pci"
          "-display gtk,gl=on"
        ];
      };

      # Enable QEMU Guest Agent
      services.qemuGuest.enable = true;

      # VM-specific packages and servicesvm
      environment.systemPackages = with pkgs; [
        # Install SPICE agent and utilities
        spice-vdagent # This enables auto-resize and clipboard sharing
      ];

      # For better graphics performance (if using VirtIO)
      boot.initrd.kernelModules = ["virtio_gpu"];

      # Enable X11 auto-resize for SPICE
      services.xserver.videoDrivers = ["qxl"]; # Use "virtio" if using VirtIO graphics

      # For Wayland-based desktops like Hyprland
      hardware.opengl.enable = true;

      # A daemon that provides clipboard sharing and auto-resize
      services.spice-vdagentd.enable = true;
    };

    # Network configuration
    networking = {
      networkmanager.enable = true;
    };

    # Time zone and locale
    time.timeZone = "America/Chicago";
    i18n.defaultLocale = "en_US.UTF-8";

    services = {
      openssh.enable = true;

      # A daemon that automatically adjusts CPU frequency based on usage
      auto-cpufreq.enable = true;

      # A shell daemon created to manage processes' IO and CPU priorities, with community-driven set of rules
      ananicy = {
        enable = true;
        package = pkgs.ananicy-cpp;
      };
    };

    # A compiler cache that can speed up build times
    programs.ccache.enable = true;

    security = {
      # A daemon that allows for real-time kernel parameters to be changed
      rtkit.enable = true;

      sudo = {
        wheelNeedsPassword = false;
        extraRules = [
          {
            users = ["simonwjackson"];

            commands = [
              {
                command = "ALL";
                options = ["NOPASSWD" "SETENV"];
              }
            ];
          }
        ];
      };

      # Increase open file limit for sudoers
      pam.loginLimits = [
        {
          domain = "@wheel";
          type = "-";
          item = "memlock";
          value = "unlimited";
        }
        {
          domain = "simonwjackson";
          type = "soft";
          item = "memlock";
          value = "unlimited";
        }
        {
          domain = "simonwjackson";
          type = "hard";
          item = "memlock";
          value = "unlimited";
        }
      ];
    };

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
      '';
      # TODO: Add age secrets
      # !include ${config.age.secrets."user-simonwjackson-github-token-nix".path};
    };
  };
}

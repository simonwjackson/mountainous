{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkDefault mkIf mkOption types optionalAttrs;
  cfg = config.mountainous.presets.core;
  syncthingUser = config.mountainous.features.syncthing.user;
  passwordSecretFile = ../../secrets/hosts/${config.networking.hostName}/simonwjackson-password-hash.age;
  hasPasswordSecret = builtins.pathExists passwordSecretFile;
in {
  options.mountainous.presets.core = {
    passwordHash = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Default hashed password for simonwjackson when no per-host agenix secret exists.";
    };
  };

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];

    mountainous.features.atuin.enable = mkDefault true;
    mountainous.features.ssh.server.enable = mkDefault true;
    mountainous.features.starship.enable = mkDefault true;

    nixpkgs.config.allowUnfree = true;
    networking.useDHCP = mkDefault true;

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

    nix = {
      package = mkDefault pkgs.nixVersions.latest;
      optimise.automatic = mkDefault true;
      settings = {
        experimental-features = ["nix-command" "flakes"];
        trusted-users = ["root" "@wheel" "simonwjackson"];
        auto-optimise-store = mkDefault true;
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
      };
    };

    # MagicDNS
    networking.nameservers = mkDefault ["100.100.100.100" "1.1.1.1"];
    networking.search = mkDefault ["hummingbird-lake.ts.net"];

    mountainous.features.syncthing.shares = {
      pi-config = {
        path = mkDefault "/home/${syncthingUser}/.pi";
        ignorePatterns = mkDefault [
          "**/.git"
          "**/.git/**"
          "**/node_modules"
          "**/node_modules/**"
          "**/.direnv"
          "**/.direnv/**"
          "**/.venv"
          "**/.venv/**"
          "**/venv"
          "**/venv/**"
          "**/__pycache__"
          "**/__pycache__/**"
          "**/.mypy_cache"
          "**/.mypy_cache/**"
          "**/.pytest_cache"
          "**/.pytest_cache/**"
          "**/.ruff_cache"
          "**/.ruff_cache/**"
          "**/.cache"
          "**/.cache/**"
          "**/dist"
          "**/dist/**"
          "**/build"
          "**/build/**"
          "**/result"
          "**/result/**"
          "**/tmp"
          "**/tmp/**"
          "**/.tmp"
          "**/.tmp/**"
          "**/agent/bin"
          "**/agent/bin/**"
          "**/*.log"
        ];
      };

      biometrics.path = mkDefault "/home/${syncthingUser}/biometrics";
      fitness.path = mkDefault "/home/${syncthingUser}/fitness";
      flakey.path = mkDefault "/home/${syncthingUser}/flakey";
      omi.path = mkDefault "/home/${syncthingUser}/omi";
      research.path = mkDefault "/home/${syncthingUser}/research";
      therapy.path = mkDefault "/home/${syncthingUser}/therapy";
      transcripts.path = mkDefault "/home/${syncthingUser}/transcripts";
      nutrition.path = mkDefault "/home/${syncthingUser}/.local/share/nutrition";
      tasks.path = mkDefault "/home/${syncthingUser}/.local/share/tasks";
    };

    # OCI config needs a custom path (auto-discovered ownership is fine)
    age.secrets.oci-config.path = "/home/simonwjackson/.oci/config";

    users.users.simonwjackson =
      {
        isNormalUser = true;
        extraGroups = ["wheel"];
      }
      // optionalAttrs hasPasswordSecret {
        hashedPasswordFile = config.age.secrets.simonwjackson-password-hash.path;
      }
      // optionalAttrs (!hasPasswordSecret && cfg.passwordHash != null) {
        hashedPassword = mkDefault cfg.passwordHash;
      };

    networking.firewall = {
      enable = mkDefault true;
      allowedTCPPorts = mkDefault [];
      allowedUDPPorts = mkDefault [41641];
      trustedInterfaces = ["tailscale0"];
    };
  };
}

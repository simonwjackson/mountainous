{
  config,
  lib,
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
    nixpkgs.config.allowUnfree = true;
    networking.useDHCP = mkDefault true;
    i18n.defaultLocale = "en_US.UTF-8";

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

    age.secrets.simonwjackson-password-hash = mkIf hasPasswordSecret {
      file = passwordSecretFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    age.secrets."serper-api-key" = {
      file = ../../secrets/serper-api-key.age;
      owner = "simonwjackson";
      mode = "0400";
    };

    age.secrets."brave-api-key" = {
      file = ../../secrets/brave-api-key.age;
      owner = "simonwjackson";
      mode = "0400";
    };

    age.secrets."oci-config" = {
      file = ../../secrets/oci-config.age;
      owner = "simonwjackson";
      mode = "0400";
      path = "/home/simonwjackson/.oci/config";
    };

    age.secrets."oci-api-key" = {
      file = ../../secrets/oci-api-key.age;
      owner = "simonwjackson";
      mode = "0400";
    };

    age.secrets."oci-yari-key" = {
      file = ../../secrets/oci-yari-key.age;
      owner = "simonwjackson";
      mode = "0400";
    };

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

    services.fail2ban = {
      enable = mkDefault true;
      ignoreIP = mkDefault ["100.64.0.0/10"];
      maxretry = mkDefault 3;
      bantime = mkDefault "1h";
      bantime-increment = {
        enable = mkDefault true;
        maxtime = mkDefault "168h";
      };
    };

    services.openssh = {
      enable = mkDefault true;
      settings = {
        PermitRootLogin = mkDefault "prohibit-password";
        PasswordAuthentication = mkDefault false;
      };
    };

    networking.firewall = {
      enable = mkDefault true;
      allowedTCPPorts = mkDefault [];
      allowedUDPPorts = mkDefault [41641];
      trustedInterfaces = mkDefault ["tailscale0"];
    };
  };
}

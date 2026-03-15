{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkIf mkOption types optionalAttrs;
  cfg = config.mountainous.presets.core;
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
    age.secrets.simonwjackson-password-hash = mkIf hasPasswordSecret {
      file = passwordSecretFile;
      owner = "root";
      group = "root";
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

    networking.firewall = {
      enable = mkDefault true;
      allowedTCPPorts = mkDefault [];
      allowedUDPPorts = mkDefault [41641];
      trustedInterfaces = mkDefault ["tailscale0"];
    };

    mountainous.tailscale.extraSetFlags = mkDefault ["--netfilter-mode=nodivert"];
  };
}

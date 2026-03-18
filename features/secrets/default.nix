{
  config,
  lib,
  mountainousPlatform ? "nixos",
  ...
}: let
  inherit (lib) mkEnableOption mkOption optional types;
in {
  imports = optional (mountainousPlatform == "nixos") ./nixos.nix;

  options.mountainous.features.secrets = {
    enable = mkEnableOption "convention-based secrets auto-discovery";

    hostname = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Hostname used to scope host-specific secrets.
        Auto-set from networking.hostName on NixOS.
      '';
    };

    identityFile = mkOption {
      type = types.str;
      default = "";
      description = "Path to the age/SSH identity file for decryption (droid).";
    };

    secretsDir = mkOption {
      type = types.str;
      default = "/run/agenix";
      description = "Directory where decrypted secrets are stored.";
    };

    path = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = ''
        Platform-agnostic mapping of secret name → decrypted file path.
        Auto-populated by the NixOS or droid backend.
      '';
    };

    # Kept for backward-compatible manual additions on droid.
    secrets = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          file = mkOption {
            type = types.path;
            description = "Path to the age-encrypted secret file.";
          };

          mode = mkOption {
            type = types.str;
            default = "0400";
            description = "File permissions for the decrypted secret.";
          };

          path = mkOption {
            type = types.str;
            default = "${config.mountainous.features.secrets.secretsDir}/${name}";
            description = "Path where the decrypted secret will be placed.";
          };
        };
      }));
      default = {};
      description = "Extra manually-declared secrets (merged with auto-discovered).";
    };
  };
}

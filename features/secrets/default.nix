{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.secrets;

  secretType = types.submodule ({name, ...}: {
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
        default = "${cfg.secretsDir}/${name}";
        description = "Path where the decrypted secret will be placed.";
      };
    };
  });
in {
  options.mountainous.features.secrets = {
    enable = mkEnableOption "age-based secrets management";

    identityFile = mkOption {
      type = types.str;
      default = "";
      description = "Path to the age/SSH identity file for decryption.";
    };

    secretsDir = mkOption {
      type = types.str;
      default = "";
      description = "Directory where decrypted secrets are stored.";
    };

    secrets = mkOption {
      type = types.attrsOf secretType;
      default = {};
      description = "Secrets to decrypt and manage.";
    };
  };
}

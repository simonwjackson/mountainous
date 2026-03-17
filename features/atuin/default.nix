{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.atuin;
in {
  options.mountainous.features.atuin = {
    enable = mkEnableOption "Atuin shell history sync";

    keyPath = mkOption {
      type = types.str;
      default = "${config.mountainous.features.secrets.secretsDir}/atuin-key";
      description = "Path to the Atuin key file.";
    };

    sessionPath = mkOption {
      type = types.str;
      default = "${config.mountainous.features.secrets.secretsDir}/atuin-session";
      description = "Path to the Atuin session file.";
    };
  };
}

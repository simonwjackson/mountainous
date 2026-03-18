{
  config,
  lib,
  mountainousPlatform ? "nixos",
  ...
}: let
  inherit (lib) mkEnableOption mkOption optional types;
  cfg = config.mountainous.features.atuin;
in {
  imports = optional (mountainousPlatform == "nixos") ./nixos.nix;

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

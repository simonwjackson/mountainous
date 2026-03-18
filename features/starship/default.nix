{
  config,
  lib,
  mountainousPlatform ? "nixos",
  ...
}: let
  inherit (lib) mkEnableOption mkOption optional types;
  cfg = config.mountainous.features.starship;
in {
  imports = optional (mountainousPlatform == "nixos") ./nixos.nix;

  options.mountainous.features.starship = {
    enable = mkEnableOption "Starship prompt";

    hostName = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "usu";
      description = "Hostname label to show in the prompt instead of the system hostname.";
    };
  };
}

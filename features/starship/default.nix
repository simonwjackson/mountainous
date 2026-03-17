{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.starship;
in {
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

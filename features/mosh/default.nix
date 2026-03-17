{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.mosh;
in {
  options.mountainous.features.mosh = {
    enable = mkEnableOption "Mosh remote shell support";

    ports = mkOption {
      type = types.str;
      default = "60000:60010";
      example = "60000:60010";
      description = "UDP port range used by mosh-server for remote sessions.";
    };
  };
}

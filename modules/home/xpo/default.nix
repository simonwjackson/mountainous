{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.mountainous.xpo;
  package = pkgs.mountainous.xpo;
in {
  options.mountainous.xpo = {
    enable = lib.mkEnableOption "xpo";

    defaultServer = lib.mkOption {
      default = null;
      type = with lib.types; nullOr str;
      description = ''
        Default SSH server/endpoint to use when tunneling.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = [package];
      sessionVariables.XPO_SERVER = lib.optionalString (cfg.defaultServer != null) cfg.defaultServer;
    };
  };
}

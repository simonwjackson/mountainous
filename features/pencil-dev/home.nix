{
  lib,
  osConfig ? {},
  ...
}: let
  cfg = osConfig.mountainous.features.pencil-dev or {};
  enabled = cfg.enable or false;
in {
  config = lib.mkIf enabled {
    home.packages = [
      cfg.package
      cfg.cliPackage
    ];
  };
}

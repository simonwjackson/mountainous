{
  osConfig,
  lib,
  ...
}: let
  cfg = osConfig.mountainous.features.syncthing;
in {
  config = lib.mkIf cfg.enable {};
}

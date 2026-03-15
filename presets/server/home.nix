{
  osConfig,
  lib,
  ...
}: let
  cfg = osConfig.mountainous.presets.server;
in {
  config = lib.mkIf cfg.enable {};
}

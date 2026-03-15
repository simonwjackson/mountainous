{
  osConfig,
  lib,
  ...
}: let
  cfg = osConfig.mountainous.presets.core;
in {
  config = lib.mkIf cfg.enable {};
}

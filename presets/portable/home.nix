{
  osConfig,
  lib,
  ...
}: let
  cfg = osConfig.mountainous.presets.portable;
in {
  config = lib.mkIf cfg.enable {};
}

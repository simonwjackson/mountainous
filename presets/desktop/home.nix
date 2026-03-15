{
  osConfig,
  lib,
  ...
}: let
  cfg = osConfig.mountainous.presets.desktop;
in {
  imports = [
    ../../modules/home/theme
  ];

  config = lib.mkIf cfg.enable {
    mountainous.theme = {
      enable = lib.mkDefault true;
      defaultMode = lib.mkDefault "dark";
    };
  };
}

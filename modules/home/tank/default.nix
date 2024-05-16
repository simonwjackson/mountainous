{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.types) str;

  cfg = config.mountainous.tank;
in {
  options.mountainous.tank = {
    enable = lib.mkEnableOption "Whether to enable a centralized location for your data";

    path = lib.mkOption {
      type = str;
      description = ''
        Path to a common mass storage area
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg = {
      userDirs = {
        enable = true;
        createDirectories = false;
        desktop = "${cfg.path}/desktop";
        documents = "${cfg.path}/documents";
        download = "${cfg.path}/downloads";
        music = "${cfg.path}/music";
        pictures = "${cfg.path}/photos";
      };
    };
  };
}

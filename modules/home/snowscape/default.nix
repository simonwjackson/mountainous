{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.simonwjackson.snowscape;
  package = pkgs.snowscape;
in {
  options.simonwjackson.snowscape = {
    enable = lib.mkEnableOption "snowscape";

    path = lib.mkOption {
      default = "/glacier/snowscape/";
      type = with lib.types; str;
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

{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption;

  cfg = config.mountainous.lf;
in {
  options.mountainous.lf = {
    enable = mkEnableOption "Whether to enable lf";
  };

  config = lib.mkIf cfg.enable {
    programs.lf = {
      enable = true;
      extraConfig = builtins.readFile ./lfrc;
    };

    home.file = {
      "./.local/bin/pv" = {
        source = ./pv.sh;
      };

      "./.config/lf/colors" = {
        source = ./colors;
      };

      "./.config/lf/icons" = {
        source = ./icons;
      };
    };
  };
}

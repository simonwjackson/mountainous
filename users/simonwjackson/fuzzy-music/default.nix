{ config, lib, pkgs, ... }:

let
  cfg = config.programs.fuzzy-music;

in
{
  options.programs.fuzzy-music = {
    enable = lib.mkEnableOption "fuzzy-music";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      beets
      jq
      fzf
      sxhkd
      gawk
    ];

    services.sxhkd.extraConfig = lib.mkMerge [
      (builtins.readFile ./sxhkdrc)
    ];

    home.file.".local/bin/fuzzy-music" = {
      text = builtins.readFile ./fuzzy-music.sh;
      executable = true;
    };
  };
}

{
  lib,
  pkgs,
}: let
  runtimeInputs = with pkgs; [
    imagemagick
    entr
    hyprpaper
    jq
    gum
    hyprland
    util-linux
  ];
in
  pkgs.writeShellApplication {
    inherit runtimeInputs;
    name = "blur-image";
    text = builtins.readFile ./blur-image.sh;
  }
  // {
    meta = with lib; {
      licenses = licenses.mit;
      platforms = platforms.all;
    };
  }

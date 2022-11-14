{ config, pkgs, ... }:

let
  script = pkgs.writeShellApplication
    {
      name = "dual-screen-with-tablet";

      runtimeInputs = with pkgs; [
        xorg.xrandr
      ];

      text = builtins.readFile ./dual-screen-with-tablet.sh;
    };

in
{
  home.packages = [
    script
  ];
}

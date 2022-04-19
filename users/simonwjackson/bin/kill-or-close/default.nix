{ config, pkgs, ... }:

let
  script = pkgs.writeShellApplication
    {
      name = "kill-or-close";

      runtimeInputs = with pkgs; [
        xdotool
        bspwm
      ];

      text = builtins.readFile ./kill-or-close.sh;
    };

in
{
  home.packages = [
    script
  ];
}

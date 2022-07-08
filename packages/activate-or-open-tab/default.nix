{ config, pkgs, ... }:

let
  script = pkgs.writeShellApplication
    {
      name = "activate-or-open-tab";

      runtimeInputs = with pkgs; [
        xdotool
        brotab
      ];

      text = builtins.readFile ./activate-or-open-tab.sh;
    };

in
{
  home.packages = [
    script
  ];
}

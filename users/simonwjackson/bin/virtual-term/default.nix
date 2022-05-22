{ config, pkgs, ... }:

let
  script = pkgs.writeShellApplication
    {
      name = "virtual-term";

      runtimeInputs = with pkgs; [
        kitty
        tmux
        xdotool
      ];

      text = builtins.readFile ./virtual-term.sh;
    };

in
{
  home.packages = [
    script
  ];
}

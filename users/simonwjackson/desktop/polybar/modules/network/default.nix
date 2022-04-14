{ config, pkgs, ... }:

let
  mkBin = (import ../../../../../../utils/mkBin.nix { inherit config pkgs; });

  name = "network";
  fullPath = mkBin
    {
      name = name;
      text = builtins.readFile ./network.sh;
      deps = with pkgs; [
        networkmanager
      ];
    };

in
''
  [module/${name}]
  type = "custom/script"
  exec = ${fullPath}
  format-foreground = ''${colors.foreground-dim}
  click-left = kitty-popup wifi-menu
''

{ config, pkgs, ... }:

let
  mkBin = (import ../../../../../../utils/mkBin.nix { inherit config pkgs; });

  name = "time";
  fullPath = mkBin
    {
      name = name;
      text = ''
        TZ=US/Central date '+%-l:%M'
      '';
      deps = with pkgs; [
        coreutils-full
      ];
    };

in
''
  [module/${name}]
  type = "custom/script"
  exec = ${fullPath}
  format-foreground = ''${colors.foreground-dim}
''


{ config, pkgs, ... }:

let
  mkBin = (import ../../../../../../utils/mkBin.nix { inherit config pkgs; });
  name = "surfce-performance";

  fullPath = mkBin
    {
      name = name;
      deps = with pkgs; [ surface-control ];
      text = builtins.readFile "./${surface-performance}.sh";
    };

in
''
  [module/${name}]
  type = "custom/script"
  exec = ${fullPath}
''

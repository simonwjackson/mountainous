{ config, pkgs, ... }:

let
  mkBin = (import ../../../../../../utils/mkBin.nix { inherit config pkgs; });

  name = "check-reddit";
  fullPath = mkBin
    {
      name = name;
      deps = with pkgs; [ jq curl ];
      text = builtins.readFile ./check-reddit.sh;
    };

in
''
  [module/${name}]
  type = "custom/script"
  exec = ${fullPath}
''

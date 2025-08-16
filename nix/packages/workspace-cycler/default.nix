{
  lib,
  inputs,
  pkgs,
  stdenv,
  ...
}:

pkgs.writeShellScriptBin "workspaceCycler" ''
  #!${pkgs.bash}/bin/bash
  export PATH="${lib.makeBinPath [pkgs.jq pkgs.hyprland]}:$PATH"

  ${builtins.readFile ./workspace-cycle.sh}
''
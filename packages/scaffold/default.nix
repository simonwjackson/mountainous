{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "scaffold";
  runtimeInputs = with pkgs; [
    coreutils
    git
  ];
  text = builtins.readFile ./scaffold.sh;
} 
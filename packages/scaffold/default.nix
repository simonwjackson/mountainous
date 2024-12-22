{pkgs, ...}:
pkgs.writeShellApplication {
  name = "scaffold";
  runtimeInputs = with pkgs; [
    coreutils
    git
    age
  ];
  text = builtins.readFile ./scaffold.sh;
}
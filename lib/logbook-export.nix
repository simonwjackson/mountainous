{ pkgs }:
pkgs.writeShellApplication {
  name = "logbook-export";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.sqlite
  ];
  text = builtins.readFile ../modules/logbook-export.sh;
}

{pkgs, ...}:
pkgs.writeShellApplication {
  name = "scaffold";
  runtimeInputs = with pkgs; [
    coreutils
    git
    age
    openssl
    gnused
    unixtools.xxd
  ];
  text = builtins.readFile ./scaffold.sh;
}

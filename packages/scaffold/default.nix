{
  inputs,
  pkgs,
  ...
}:
pkgs.writeShellApplication {
  name = "scaffold";
  runtimeInputs = with pkgs; [
    coreutils
    git
    age
    openssl
    gnused
    unixtools.xxd
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.agenix
  ];
  text = builtins.readFile ./scaffold.sh;
}

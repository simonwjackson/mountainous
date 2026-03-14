{
  inputs,
  lib,
  pkgs,
  ...
}:
pkgs.writeShellApplication {
  name = "deploy";
  runtimeInputs = with pkgs; [
    bash
    coreutils
    openssh
    age
    inputs.nixos-anywhere.packages.${pkgs.stdenv.hostPlatform.system}.nixos-anywhere
  ];

  text = builtins.readFile ./deploy.sh;
}

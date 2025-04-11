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
    inputs.nixos-anywhere.packages.${system}.nixos-anywhere
  ];

  text = builtins.readFile ./deploy.sh;
}

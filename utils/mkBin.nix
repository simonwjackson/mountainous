{ config, pkgs, ... }:

let
  mkBin = { name, text, deps }: pkgs.writeShellApplication
    {
      name = name;
      runtimeInputs = deps;
      text = text;
    } + "/bin/${name}";
in
mkBin

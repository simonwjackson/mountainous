{ config, pkgs, ... }:

let
  mkBin = { name, text, deps }: pkgs.writeShellApplication
    {
      name = name;
      runtimeInputs = deps;
      text = text;
    } + "/bin/${name}";
in
mkBin {
  name = "polybar-check-reddit";
  deps = with pkgs; [ jq ];
  text = builtins.readFile ./check-reddit.sh;
}

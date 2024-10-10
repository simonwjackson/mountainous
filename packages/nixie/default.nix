{
  lib,
  pkgs,
  writeShellApplication,
}:
writeShellApplication {
  name = "nixie";
  runtimeInputs = with pkgs; [
    bash
    gum
    jq
    openssh
    nix-output-monitor
    parallel
  ];
  text = builtins.readFile ./nixie.sh;
}
// {
  meta = with lib; {
    licenses = licenses.mit;
    platforms = platforms.all;
  };
}

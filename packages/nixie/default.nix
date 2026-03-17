{
  lib,
  pkgs,
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "nixie";
  runtimeInputs = with pkgs; [
    python3
    nix
    nixos-rebuild
    rsync
    openssh
  ];
  text = ''
    exec python3 ${./nixie.py} "$@"
  '';
}
// {
  meta = with lib; {
    licenses = licenses.mit;
    platforms = platforms.all;
  };
}

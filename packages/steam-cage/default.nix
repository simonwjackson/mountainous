{
  lib,
  writeShellApplication,
  cage,
  sway,
  foot,
  coreutils,
  ...
}:
writeShellApplication {
  name = "steam-cage";

  runtimeInputs = [
    cage
    sway
    foot
    coreutils
  ];

  text = builtins.readFile ./steam-cage.sh;

  meta = with lib; {
    description = "Launch Steam inside cage -> sway (kiosk-style)";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}

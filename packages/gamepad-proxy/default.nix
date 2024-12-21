{
  lib,
  python3,
  writeScriptBin,
}:
let
  pythonWithPackages = python3.withPackages (ps: with ps; [evdev]);
in
writeScriptBin "gamepad-proxy" ''
  #!${pythonWithPackages}/bin/python3
  ${builtins.readFile ./gamepad-proxy.py}
'' 
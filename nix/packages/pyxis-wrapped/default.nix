{
  pkgs,
  inputs,
  ...
}:
pkgs.writeShellScriptBin "pyxis" ''
  export PANDORA_USERNAME="$(cat /run/agenix/pandora-username)"
  export PANDORA_PASSWORD="$(cat /run/agenix/pandora-password)"
  exec ${pkgs.pyxis}/bin/pyxis "$@"
''

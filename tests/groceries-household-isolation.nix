# Focused upstream isolation diagnostic. No application derivation/check phase.
{ application }:
let
  pkgs = application.inputs.nixpkgs.legacyPackages.x86_64-linux;
  source = import (application.outPath + "/nix/source.nix") {
    src = application.outPath;
    inherit (pkgs) lib;
  };
  modules = import (application.outPath + "/nix/node-modules.nix") { inherit pkgs source; };
in
pkgs.runCommand "groceries-household-isolation" { nativeBuildInputs = [ pkgs.nodejs_24 ]; } ''
  cp -r ${source} source
  chmod -R u+w source
  cd source
  cp -r ${modules}/node_modules .
  chmod -R u+w node_modules
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"
  node node_modules/vitest/vitest.mjs run src/storage/household.test.ts --maxWorkers 1 --testTimeout 30000
  touch "$out"
''

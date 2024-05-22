{lib, ...}: let
  inherit (lib.snowfall.fs) get-file;
in {
  util = rec {
    allArchitectures = builtins.attrNames (builtins.readDir (get-file "systems"));
    getAllHosts = arch: builtins.attrNames (builtins.readDir (get-file "systems/${arch}"));
  };
}

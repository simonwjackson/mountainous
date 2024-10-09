{lib, ...}: let
  inherit (lib.snowfall.fs) get-file;
in rec {
  util = rec {
    allArchitectures = systems: builtins.attrNames (builtins.readDir systems);
    getAllHosts = systems: arch: builtins.attrNames (builtins.readDir "${systems}/${arch}");
  };
}

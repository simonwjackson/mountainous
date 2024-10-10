{lib, ...}: let
  inherit (lib.snowfall.fs) get-file;
in rec {
  util = rec {
    allArchitectures = systems: builtins.attrNames (builtins.readDir systems);
    getAllHosts = systems: arch: builtins.attrNames (builtins.readDir "${systems}/${arch}");
    # for tmesh
    systems = lib.snowfall.fs.get-file "systems";
    architectures = builtins.attrNames (builtins.readDir systems);
    getHosts = arch:
      builtins.attrNames (builtins.readDir (systems + "/${arch}"));

    allHosts = lib.flatten (map (arch: getHosts arch) architectures);
  };
}

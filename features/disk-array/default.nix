{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.disk-array = {
    enable = mkEnableOption "portable USB disk array with mergerfs and SnapRAID";

    pools = mkOption {
      type = types.attrsOf (types.submodule (import ./pool-options.nix {inherit lib;}));
      default = {};
      description = "Named disk pools (e.g. tank0, tank1). Each pool gets individual disk mounts, a mergerfs merged view, and optional SnapRAID.";
      example = {
        tank0 = {
          disks = [
            {
              id = "00";
              device = "/dev/disk/by-id/usb-Example_Disk_SERIAL1-0:0";
            }
          ];
        };
      };
    };
  };
}

# Standalone disko configuration for iceberg array disk formatting
# ⚠️  WARNING: This will DESTROY ALL DATA on the iceberg array disks!
#
# Usage:
#   nix run github:nix-community/disko -- --mode disko /path/to/this/file
#
# This configuration imports from config.nix to maintain DRY principles
# and ensure consistency with the mounting configuration.
let
  lib = import <nixpkgs/lib>;
  sharedConfig = import ./config.nix {inherit lib;};
  icebergConfig = sharedConfig.icebergArray;
in {
  disko.devices.disk = lib.listToAttrs (map (disk: {
      name = disk.id;
      value = {
        type = "disk";
        device = disk.device;
        content = {
          type = "gpt";
          partitions = {
            "${disk.id}.0" = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs"; # ⚠️  THIS FORMATS THE DISK
                mountpoint = icebergConfig.getDiskMountPoint icebergConfig.mountPoints disk.id;
                mountOptions = disk.mountOptions;
              };
            };
          };
        };
      };
    })
    icebergConfig.disks);
}

# The permafrost disk layout: one disk, an ESP, and one btrfs filesystem.
#
# `/` is a tmpfs, so everything not on a subvolume below is gone at boot.
# modules/permafrost.nix uses this for real hosts; tests/permafrost.nix uses
# the same function, so the test formats exactly what a host would get.
{ device, rootSize }:
let
  btrfsOptions = [
    "compress=zstd:1"
    "noatime"
  ];
  subvolume = mountpoint: {
    inherit mountpoint;
    mountOptions = btrfsOptions;
  };
in
{
  disko.devices = {
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "size=${rootSize}"
        "mode=755"
      ];
    };

    disk.main = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            priority = 1;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            priority = 2;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "/@nix" = subvolume "/nix";
                "/@home" = subvolume "/home";
                # Declared system state: host keys, machine-id, logs, UID map.
                "/@permafrost" = subvolume "/permafrost";
                # Tailscale's identity has its own subvolume, mounted directly
                # at its real path. There is no bind mount or symlink to set up
                # before tailscaled starts, so nothing can race it.
                "/@tailscale" = subvolume "/var/lib/tailscale";
              };
            };
          };
        };
      };
    };
  };
}

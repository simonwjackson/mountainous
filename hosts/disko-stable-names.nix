# Disko formats the disk at the path each layout names. Kernel names such as
# /dev/sda follow discovery order, so a USB or Thunderbolt disk can take the
# name during an install and disko would wipe it. Require stable names.
{
  config,
  lib,
  ...
}: let
  disks = config.disko.devices.disk or {};
  unstable =
    lib.filterAttrs (_: disk: lib.hasPrefix "/dev/sd" disk.device) disks;
in {
  assertions = [
    {
      assertion = unstable == {};
      message = ''
        disko: these disks use a kernel name that can point at another disk:
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: disk: "  ${name} = ${disk.device}") unstable)}
        Use the /dev/disk/by-id/... name instead (run `ls /dev/disk/by-id/` on the machine).
      '';
    }
  ];
}

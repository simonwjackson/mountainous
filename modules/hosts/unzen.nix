# Intel i7-9700K / ASRock Z390 Phantom Gaming-ITX/ac headless server.
# Disko prepares the initial NVMe pool; applying it to hardware is destructive.
{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
        unzen-storage = import ../../tests/unzen-storage.nix {
          inherit pkgs;
          diskoLib = inputs.disko.lib;
        };
      };
    };

  nixos.hosts.unzen = {
    system = "x86_64-linux";
    layers = [
      "base"
      "server"
    ];

    module = {
      imports = [
        inputs.disko.nixosModules.disko
        ../../disks/unzen.nix
      ];
      mountainous.features.cliproxyapi-updater.enable = true;
      hardware.cpu.intel.updateMicrocode = true;
      boot.supportedFilesystems = [ "bcachefs" ];

      # Do not import the shared btrfs disk layer. All OS/data subvolumes
      # share the unencrypted pool. Only the small ESPs have fixed sizes.

      # Both 95 W limits completed the staged CPU + read-only SSD test.
      # No voltage offsets, temperature targets, or turbo override are set.
      services.undervolt = {
        enable = true;
        # Required by the upstream options. These encode the existing
        # 27983872 / 2440 us sysfs windows, rather than selecting new ones.
        p1 = {
          limit = 95;
          window = 28;
        };
        p2 = {
          limit = 95;
          window = 0.00244;
        };
      };
    };
  };
}

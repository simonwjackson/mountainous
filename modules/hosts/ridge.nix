# The laptop.
#
# Two things are deliberately absent. There is no hardware-configuration.nix,
# because nixos-facter writes ridge.facter.json on the machine itself. There
# are no fileSystems entries, because disko derives them from the layout below.
#
# Generate the hardware report once, as root, on the target:
#   nixos-facter -o ridge.facter.json
{ inputs, ... }:
{
  nixos.hosts.ridge = {
    system = "x86_64-linux";
    layers = [
      "base"
      "desktop"
    ];

    module = {
      imports = [ inputs.disko.nixosModules.disko ];

      hardware.facter.reportPath = ./ridge.facter.json;

      # Confirm the device name over SSH before the first deploy. A laptop
      # with NVMe is /dev/nvme0n1; SATA is /dev/sda. Writing the wrong one
      # here destroys the wrong disk.
      disko.devices.disk.main = {
        device = "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}

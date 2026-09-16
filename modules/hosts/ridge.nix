# The laptop, currently living on a USB stick.
#
# ridge is a real, writable NixOS install that happens to sit on removable
# media. You boot it, SSH in, `nixos-rebuild switch`, and the change is still
# there after a reboot. The laptop's internal disk is never touched.
#
# There is no hardware-configuration.nix and no facter report, on purpose.
# The `portable` layer carries broad drivers instead, because this system has
# to boot on whatever machine the stick is plugged into.
#
# When ridge eventually moves to the laptop's internal disk, drop `portable`,
# add a facter report, and point `device` at the internal drive.
{ inputs, ... }:
{
  nixos.hosts.ridge = {
    system = "x86_64-linux";
    layers = [
      "base"
      "desktop"
      "portable"
    ];

    module = {
      imports = [ inputs.disko.nixosModules.disko ];

      # This path is only read while partitioning. The installed system finds
      # its filesystems through /dev/disk/by-partlabel/, so the stick boots
      # regardless of which letter it lands on elsewhere.
      disko.devices.disk.main = {
        device = "/dev/sdi";
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

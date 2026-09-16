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
            # 1M BIOS Boot Partition. GRUB embeds core.img here for legacy
            # boot. Without it, grub-install refuses the i386-pc target on a
            # GPT disk, and disko-install always attempts that target because
            # it forces boot.loader.grub.devices to the install disk at
            # mkVMOverride priority. Carrying it also means the stick boots on
            # machines with no UEFI at all.
            bios = {
              size = "1M";
              type = "EF02";
              priority = 1;
            };
            ESP = {
              size = "1G";
              type = "EF00";
              priority = 2;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              priority = 3;
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

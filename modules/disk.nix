# One disk layout, for every machine that mountainous installs onto.
#
# The layout is the same everywhere: an ESP and an ext4 root, found after
# install through /dev/disk/by-partlabel/ so the same system boots no matter
# which letter the kernel hands the drive. Only two things vary, and both are
# options rather than copied blocks:
#
#   mountainous.disk.device    which drive to partition
#   mountainous.disk.biosBoot  whether to also carry a BIOS boot partition
#
# `device` is read only while partitioning. Nothing in the installed system
# depends on it, which is what lets a stick move between machines.
{
  nixos.modules.disk =
    {
      config,
      lib,
      inputs,
      ...
    }:
    let
      cfg = config.mountainous.disk;
      inherit (lib) mkOption types;
    in
    {
      imports = [ inputs.disko.nixosModules.disko ];

      options.mountainous.disk = {
        device = mkOption {
          type = types.str;
          description = ''
            The whole drive to partition. Everything on it is destroyed.

            Prefer a /dev/disk/by-id/ path. Device letters are assigned in
            probe order and move between boots; an id carries the model and
            serial, so naming the wrong drive becomes a typo that fails
            instead of a typo that erases the wrong disk.
          '';
          example = "/dev/disk/by-id/nvme-SAMSUNG_MZVL2512HCJQ_S675NX0T123456";
        };

        biosBoot = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Add a 1M EF02 BIOS boot partition so the drive also boots on
            machines with no UEFI at all.

            This is for removable media. It is not free on a fixed install:
            disko appends the install-time device path to
            boot.loader.grub.devices for any layout containing an EF02
            partition, which the portable layer then has to force back.
          '';
        };
      };

      config.disko.devices.disk.main = {
        inherit (cfg) device;
        type = "disk";
        content = {
          type = "gpt";
          partitions =
            # GRUB embeds core.img here for legacy boot. Without it,
            # grub-install refuses the i386-pc target on a GPT disk, and
            # disko-install always attempts that target because it forces
            # boot.loader.grub.devices to the install disk at mkVMOverride
            # priority.
            lib.optionalAttrs cfg.biosBoot {
              bios = {
                size = "1M";
                type = "EF02";
                priority = 1;
              };
            }
            // {
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
}

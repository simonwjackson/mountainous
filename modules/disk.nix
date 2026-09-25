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
        name = mkOption {
          type = types.strMatching "[a-z0-9-]+";
          default = "main";
          description = ''
            Disk namespace for partition labels and the LUKS mapper. Use a
            distinct name when two mountainous disks may be plugged into the
            same machine, so neither filesystem path can select the wrong one.
          '';
        };

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

        encrypt = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Encrypt the root filesystem with LUKS2, unlocked by a passphrase
            typed at boot.

            Only root is encrypted. The ESP stays readable, because UEFI
            firmware has to read it, and that is not a weakness: it holds a
            kernel and an initrd, both public build artifacts of this flake.

            Keeping /boot on the ESP also sidesteps GRUB entirely. GRUB cannot
            open a LUKS2 volume using Argon2id, the LUKS2 default KDF, so a
            layout with /boot inside the encrypted volume forces a weaker KDF.
            Here GRUB only ever reads plaintext vfat and the initrd does the
            unlocking, so the strong default stands.

            disko prompts for the passphrase once while formatting and, through
            its own initrdUnlock default, writes the matching
            boot.initrd.luks.devices entry for boot time.

            No TPM2 and no FIDO2 here. Both need systemd stage 1 and enrolment
            on the target machine, and a stick that unlocks itself on any
            machine it is plugged into is a stick that unlocks for whoever
            finds it. Moving to those later is a rebuild, not a reinstall,
            because the keyslots live on disk and stage 1 lives in the initrd.
          '';
        };
      };

      config.disko.devices.disk.${cfg.name} = {
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
                content =
                  let
                    # btrfs, not ext4, and compression is the reason.
                    #
                    # Measured against a real system closure from this flake:
                    # 60 store paths, 112,363,520 bytes, compressing to
                    # 38,563,966 at zstd:1 -- 2.91x. On flash a byte not
                    # written is wear not incurred, and every nixos-rebuild
                    # writes a fresh closure, so this is the single biggest
                    # thing available for the lifespan of a stick.
                    #
                    # Checksums are the second reason. Flash fails silently and
                    # partially; ext4 hands back the corrupted bytes without
                    # comment, btrfs names the file. On a disposable stick the
                    # data does not matter, but being told the stick is dying
                    # beats debugging a ghost.
                    #
                    # zstd:1 rather than :3 or :6. The measurements were 2.91x,
                    # 3.48x and 3.75x, so the first level buys most of the win
                    # for the least CPU on every write.
                    fs = {
                      type = "btrfs";
                      extraArgs = [ "-f" ];
                      subvolumes = {
                        "/@" = {
                          mountpoint = "/";
                          mountOptions = [
                            "compress=zstd:1"
                            "noatime"
                          ];
                        };
                        "/@home" = {
                          mountpoint = "/home";
                          mountOptions = [
                            "compress=zstd:1"
                            "noatime"
                          ];
                        };
                        # The store is the compressible part and the part
                        # rewritten on every switch. Splitting it out means it
                        # can be snapshotted, and rolled back, on its own.
                        "/@nix" = {
                          mountpoint = "/nix";
                          mountOptions = [
                            "compress=zstd:1"
                            "noatime"
                          ];
                        };
                      };
                    };
                  in
                  if cfg.encrypt then
                    {
                      type = "luks";
                      name =
                        if cfg.name == "main" then "mountainous-root" else "mountainous-${cfg.name}-root";

                      # Prompt while formatting rather than reading a file, so
                      # the passphrase never exists on disk anywhere.
                      askPassword = true;

                      settings = {
                        # Let TRIM reach the flash through LUKS. base.nix turns
                        # on fstrim, which does nothing here without it.
                        #
                        # The cost is real and worth stating: an attacker
                        # holding the stick can see which blocks are in use.
                        # Not their contents -- the shape of the used space.
                        # On media meant to survive, that trade is worth it.
                        allowDiscards = true;
                      };

                      content = fs;
                    }
                  else
                    fs;
              };
            };
        };
      };
    };
}

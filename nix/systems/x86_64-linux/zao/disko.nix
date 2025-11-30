# ============================================================================
# DEPLOYMENT STRATEGY: SD Card Boot + Btrfs RAID0 NVMe Storage
# ============================================================================
#
# CONFIGURATION:
# - SD card for EFI boot partition (simple, reliable)
# - Btrfs RAID0 on dual NVMe drives for system storage (performance)
# - Metadata mirrored (RAID1) for filesystem safety on NVMe array
#
# ============================================================================
{
  disko.devices = {
    disk = {
      # SD Card - 32GB (Boot)
      boot = {
        type = "disk";
        device = "/dev/disk/by-id/mmc-SD32G_0xfcf357fa";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "2G";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "umask=0077"
                ];
              };
            };
          };
        };
      };

      # NVMe Drive 1 - WD Blue SN570 2TB (Btrfs RAID0 member)
      # NOTE: Disko processes disks alphabetically. The btrfs must be defined
      # on the SECOND disk (blizzard.0.01) so the first partition exists when referenced.
      "blizzard.0.00" = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800890";
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              # Empty - btrfs RAID defined on blizzard.0.01
            };
          };
        };
      };

      # NVMe Drive 2 - WD Blue SN570 2TB (Btrfs RAID0 member)
      # This disk comes second alphabetically, so we define the btrfs here
      "blizzard.0.01" = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800725";
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-d raid0" # Data striped for performance
                  "-m raid1" # Metadata mirrored for safety
                  "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800890-part1" # First disk's partition
                ];
                subvolumes = {
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "nodiratime"
                      "discard=async"
                      "space_cache=v2"
                    ];
                  };

                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "nodiratime"
                      "discard=async"
                      "space_cache=v2"
                    ];
                  };

                  "@permafrost" = {
                    mountpoint = "/tundra/permafrost";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "nodiratime"
                      "discard=async"
                      "space_cache=v2"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}

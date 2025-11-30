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
              size = "512M";
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
      "blizzard.0.00" = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800890";
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-d"
                  "raid0"
                  "-m"
                  "raid1" # Metadata mirrored for safety
                  "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800725-part1"
                ];
                subvolumes = {
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

      # NVMe Drive 2 - WD Blue SN570 2TB (Btrfs RAID0 member)
      "blizzard.0.01" = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800725";
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              # Part of btrfs RAID0 with blizzard.0.00 - defined there
            };
          };
        };
      };
    };
  };
}

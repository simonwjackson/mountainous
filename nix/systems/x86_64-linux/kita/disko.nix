# ============================================================================
# DEPLOYMENT STRATEGY: RAID1 Boot from Initial Deploy
# ============================================================================
#
# This configuration uses RAID1 boot from the initial deployment.
# Cloned from zao with single SSD instead of RAID0 NVMe.
#
# CONFIGURATION:
# - RAID1 boot partition on dual USB drives (redundancy)
# - RAID1 backup partition on dual USB drives (optional storage)
# - Single SSD for system storage (replaces zao's RAID0 NVMe)
# - GRUB installed to both USB drives for boot redundancy
#
# ============================================================================
{
  disko.devices = {
    disk = {
      # USB Flash Drive 1 - SanDisk Ultra Fit 28.6GB (RAID1 boot member)
      "sleet.0.00" = {
        type = "disk";
        device = "/dev/disk/by-id/usb-SanDisk_Ultra_Fit_4C530000230426119230-0:0";
        content = {
          type = "gpt";
          partitions = {
            BOOT = {
              size = "1M";
              type = "EF02"; # GRUB MBR
            };
            ESP = {
              size = "2G";
              type = "EF00"; # EFI System Partition
              content = {
                type = "mdraid";
                name = "boot";
              };
            };
            BACKUP = {
              size = "26G";
              content = {
                type = "mdraid";
                name = "backup";
              };
            };
          };
        };
      };

      # USB Flash Drive 2 - Lexar USB Flash Drive 29.8GB (RAID1 boot member)
      "sleet.0.01" = {
        type = "disk";
        device = "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0322119070015232-0:0";
        content = {
          type = "gpt";
          partitions = {
            BOOT = {
              size = "1M";
              type = "EF02"; # GRUB MBR
            };
            ESP = {
              size = "2G";
              type = "EF00"; # EFI System Partition
              content = {
                type = "mdraid";
                name = "boot";
              };
            };
            BACKUP = {
              size = "26G";
              content = {
                type = "mdraid";
                name = "backup";
              };
            };
          };
        };
      };

      # Main SSD - Kingston SUV500M8240G 224GB (System storage)
      "blizzard.0.00" = {
        type = "disk";
        device = "/dev/disk/by-id/ata-KINGSTON_SUV500M8240G_50026B7683B6CE9D";
        content = {
          type = "gpt";
          partitions = {
            primary = {
              name = "disk-blizzard.0.00-primary";
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/tundra/permafrost";
              };
            };
          };
        };
      };
    };

    mdadm = {
      # RAID1 Boot partition on USB drives
      boot = {
        type = "mdadm";
        level = 1; # RAID1 (mirror)
        metadata = "1.0"; # Boot-compatible metadata
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
        };
      };

      # RAID1 Backup partition on USB drives
      backup = {
        type = "mdadm";
        level = 1; # RAID1 (mirror)
        metadata = "1.2"; # Standard metadata
        content = {
          type = "filesystem";
          format = "f2fs"; # Flash-Friendly File System
          mountpoint = "/tundra/usb-backup";
          mountOptions = [
            "noatime"
            "nodiratime"
            "background_gc=on" # Background garbage collection
            "gc_merge" # Merge GC operations
            "lazytime" # Lazy inode timestamp updates
          ];
        };
      };
    };
  };
}

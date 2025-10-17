# ============================================================================
# DEPLOYMENT STRATEGY: RAID1 Boot from Initial Deploy
# ============================================================================
#
# This configuration uses RAID1 boot from the initial deployment.
# The mdadm symlink workaround in deploy.sh handles Hetzner rescue udev issues.
#
# CONFIGURATION:
# - RAID1 boot partition on dual Lexar USB drives (redundancy)
# - RAID1 backup partition on dual USB drives (optional storage)
# - RAID0 system partition on dual WD Blue SN570 NVMe drives (performance)
# - GRUB installed to both USB drives for boot redundancy
#
# ============================================================================
{
  disko.devices = {
    disk = {
      # USB Flash Drive 1 - Lexar 29.8GB (RAID1 boot member)
      "sleet.0.00" = {
        type = "disk";
        device = "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0374119080022027-0:0";
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
              size = "27G";
              content = {
                type = "mdraid";
                name = "backup";
              };
            };
          };
        };
      };

      # USB Flash Drive 2 - Lexar 29.8GB (RAID1 boot member)
      "sleet.0.01" = {
        type = "disk";
        device = "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0330119070016269-0:0";
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
              size = "27G";
              content = {
                type = "mdraid";
                name = "backup";
              };
            };
          };
        };
      };

      # NVMe Drive 1 - WD Blue SN570 2TB (System array: blizzard0)
      "blizzard.0.00" = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800890";
        content = {
          type = "gpt";
          partitions = {
            mdadm = {
              size = "1850G";
              content = {
                type = "mdraid";
                name = "blizzard0";
              };
            };
          };
        };
      };

      # NVMe Drive 2 - WD Blue SN570 2TB (System array: blizzard0)
      "blizzard.0.01" = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800725";
        content = {
          type = "gpt";
          partitions = {
            mdadm = {
              size = "1850G";
              content = {
                type = "mdraid";
                name = "blizzard0";
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

      # RAID0 System partition on NVMe drives
      blizzard0 = {
        type = "mdadm";
        level = 0; # RAID0 (performance)
        metadata = "1.2"; # Standard metadata for non-boot arrays
        content = {
          type = "gpt";
          partitions = {
            primary = {
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
  };
}

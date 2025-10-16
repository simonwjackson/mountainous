# ============================================================================
# DEPLOYMENT STRATEGY: Single USB Boot → RAID1 Boot Migration
# ============================================================================
#
# INITIAL DEPLOY (Current Configuration):
# - Uses ONLY ONE USB drive for /boot (no RAID, avoids mdadm timing issues)
# - Keeps second USB available but unused during initial nixos-anywhere deploy
# - NVMe RAID0 works normally
#
# AFTER SUCCESSFUL BOOT:
# 1. Uncomment the second USB drive configuration below
# 2. Uncomment the RAID1 boot mdadm configuration
# 3. Change first USB ESP content from "filesystem" back to "mdraid"
# 4. Optionally: Uncomment backup RAID configuration
# 5. Run: sudo nixos-rebuild switch --install-bootloader
# 6. GRUB will install to both USBs and create RAID1 boot array
#
# ============================================================================
{
  disko.devices = {
    disk = {
      # USB Flash Drive 1 - Lexar 29.8GB (Primary boot - NON-RAID for initial deploy)
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
              # INITIAL DEPLOY: Direct filesystem mount (no RAID)
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
              # AFTER FIRST BOOT: Uncomment below and comment out above to enable RAID1
              # content = {
              #   type = "mdraid";
              #   name = "boot";
              # };
            };
            # BACKUP partition - uncomment after first boot if needed
            # BACKUP = {
            #   size = "27G";
            #   content = {
            #     type = "mdraid";
            #     name = "backup";
            #   };
            # };
          };
        };
      };

      # USB Flash Drive 2 - Lexar 29.8GB (DISABLED for initial deploy)
      # UNCOMMENT AFTER FIRST BOOT to enable RAID1 boot redundancy
      # "sleet.0.01" = {
      #   type = "disk";
      #   device = "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0322119070015232-0:0";
      #   content = {
      #     type = "gpt";
      #     partitions = {
      #       BOOT = {
      #         size = "1M";
      #         type = "EF02"; # GRUB MBR
      #       };
      #       ESP = {
      #         size = "2G";
      #         type = "EF00"; # EFI System Partition
      #         content = {
      #           type = "mdraid";
      #           name = "boot";
      #         };
      #       };
      #       BACKUP = {
      #         size = "27G";
      #         content = {
      #           type = "mdraid";
      #           name = "backup";
      #         };
      #       };
      #     };
      #   };
      # };

      # NVMe Drive 1 - WD Blue SN570 2TB (System array: blizzard)
      "blizzard.0.00" = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800890";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # GRUB MBR
            };
            mdadm = {
              size = "1850G";
              content = {
                type = "mdraid";
                name = "blizzard";
              };
            };
          };
        };
      };

      # NVMe Drive 2 - WD Blue SN570 2TB (System array: blizzard)
      "blizzard.0.01" = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800725";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # GRUB MBR
            };
            mdadm = {
              size = "1850G";
              content = {
                type = "mdraid";
                name = "blizzard";
              };
            };
          };
        };
      };
    };

    mdadm = {
      # RAID1 Boot partition on USB drives - DISABLED for initial deploy
      # UNCOMMENT AFTER FIRST BOOT (after uncommenting second USB above)
      # boot = {
      #   type = "mdadm";
      #   level = 1; # RAID1 (mirror)
      #   metadata = "1.0"; # Boot-compatible metadata
      #   content = {
      #     type = "filesystem";
      #     format = "vfat";
      #     mountpoint = "/boot";
      #   };
      # };

      # RAID1 Backup partition on USB drives - DISABLED for initial deploy
      # UNCOMMENT AFTER FIRST BOOT if you want backup partition
      # backup = {
      #   type = "mdadm";
      #   level = 1; # RAID1 (mirror)
      #   metadata = "1.2"; # Standard metadata
      #   content = {
      #     type = "filesystem";
      #     format = "f2fs"; # Flash-Friendly File System
      #     mountpoint = "/tundra/usb-backup";
      #     mountOptions = [
      #       "noatime"
      #       "nodiratime"
      #       "background_gc=on" # Background garbage collection
      #       "gc_merge" # Merge GC operations
      #       "lazytime" # Lazy inode timestamp updates
      #     ];
      #   };
      # };

      # RAID0 System partition on NVMe drives (ACTIVE - stays enabled)
      blizzard = {
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
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}

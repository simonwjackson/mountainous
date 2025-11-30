# ============================================================================
# DEPLOYMENT STRATEGY: Single Kingston SSD
# ============================================================================
#
# This configuration uses a single Kingston SSD for boot and storage.
#
# CONFIGURATION:
# - Kingston SUV500M8240G 224GB SSD (Boot + System storage)
#   - GRUB MBR partition (1M) for legacy BIOS compatibility
#   - ESP partition (2GB) for EFI boot
#   - Main btrfs partition with standard subvolumes
# - Standard btrfs subvolumes for nix, logs, and permafrost
#
# ============================================================================
{
  disko.devices = {
    disk = {
      # Kingston SSD - SUV500M8240G 224GB (Boot + System storage)
      main = {
        type = "disk";
        device = "/dev/disk/by-id/ata-KINGSTON_SUV500M8240G_50026B7683B6CE9D";
        content = {
          type = "gpt";
          partitions = {
            BOOT = {
              size = "1M";
              type = "EF02"; # GRUB MBR for legacy BIOS compatibility
            };
            ESP = {
              size = "2G";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"];
              };
            };
          };
        };
      };
    };
  };
}

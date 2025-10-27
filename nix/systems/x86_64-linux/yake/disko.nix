# ============================================================================
# Oracle Cloud VM Disk Configuration
# ============================================================================
#
# Simple single-disk layout for Oracle Cloud VM.Standard.E2.1.Micro
#
# CONFIGURATION:
# - 512MB EFI System Partition for boot
# - 2GB swap partition (recommended for 1GB RAM instances)
# - ~47.5GB root filesystem (xfs)
#
# ============================================================================
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
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
              };
            };
            swap = {
              size = "2G";
              content = {
                type = "swap";
                resumeDevice = true;
              };
            };
            root = {
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

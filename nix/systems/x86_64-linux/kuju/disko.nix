# ============================================================================
# DEPLOYMENT STRATEGY: KIOXIA EXCERIA PLUS G3 NVMe SSD
# ============================================================================
#
# This configuration uses a KIOXIA EXCERIA PLUS G3 1.8TB NVMe SSD for a
# portable gaming device (GPD G1617-02).
#
# CONFIGURATION:
# - KIOXIA EXCERIA PLUS G3 SSD 1.8TB NVMe (Boot + System storage)
#   - ESP partition (2GB) for UEFI boot (no GRUB MBR - pure UEFI)
#   - Swap partition (32GB) for hibernate with 24GB RAM
#   - Main btrfs partition with standard subvolumes
# - Standard btrfs subvolumes for nix, logs, and permafrost
#
# DEVICE NOTES:
# - AMD Ryzen AI 9 HX 370 (12 cores/24 threads, Zen 5)
# - 24GB RAM - swap sized at ~1.3x for hibernation support
# - UEFI boot only (no legacy BIOS)
#
# ============================================================================
{
  disko.devices = {
    disk = {
      # KIOXIA EXCERIA PLUS G3 1.8TB NVMe SSD
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-KIOXIA-EXCERIA_PLUS_G3_SSD_6FAKS1DUZ0E8";
        content = {
          type = "gpt";
          partitions = {
            # EFI boot partition (pure UEFI, no GRUB MBR needed)
            ESP = {
              size = "2G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "umask=0077" # Secure boot partition
                ];
              };
            };

            # Swap partition (32GB for hibernate support with 24GB RAM)
            # Using ~1.3x RAM size for safe hibernation
            swap = {
              size = "32G";
              content = {
                type = "swap";
                resumeDevice = true; # Enable hibernate resume
              };
            };

            # Root partition with Btrfs (rest of disk ~1.77TB)
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"]; # Force if needed

                # Btrfs subvolumes for persistent storage
                # Following hotaka/kita pattern: separate subvolumes for /nix and /var/log
                # This avoids tmpfs issues during installation
                subvolumes = {
                  # Nix store subvolume (persistent, direct mount)
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

                  # System logs subvolume (persistent, direct mount)
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

                  # Other persistent data (home, machine-id, etc.)
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

# ============================================================================
# AYANEO AIR (hotaka) - XFS + Impermanence Configuration
# ============================================================================
#
# Gaming handheld optimized configuration:
# - XFS filesystem for maximum gaming performance
# - NO encryption (no keyboard input available on handheld)
# - tmpfs root (impermanence - ephemeral system state)
# - Persistent storage at /tundra/permafrost
# - 16GB swap for hibernate support
#
# Device: 512GB NVMe SSD (NVME SSD 512GB)
# Path: /dev/nvme0n1
#
# Performance optimizations for gaming:
# - XFS: Better random I/O than btrfs (shader compilation, saves)
# - XFS: Lower CPU overhead = better battery life
# - XFS: Direct writes = less SSD wear
# - noatime: Reduce write operations
# - discard: TRIM for SSD health
#
# Note: No LUKS encryption because:
# - No physical keyboard on handheld for passphrase entry
# - Broken fingerprint sensor can't be used
# - On-screen keyboard at boot is impractical
#
# ============================================================================
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            # EFI Boot Partition
            ESP = {
              priority = 1;
              size = "512M";
              type = "EF00";
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

            # Swap Partition (16GB for hibernate with 13GB RAM)
            swap = {
              priority = 2;
              size = "16G";
              content = {
                type = "swap";
                discardPolicy = "both"; # TRIM support
                resumeDevice = true; # Enable hibernate
              };
            };

            # Root Partition (remaining space)
            # Direct XFS - no encryption (no keyboard for passphrase entry)
            root = {
              priority = 3;
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/tundra/permafrost";

                # XFS mount options optimized for gaming SSD
                mountOptions = [
                  # Performance optimizations
                  "noatime"           # Don't update access times (reduces writes)
                  "nodiratime"        # Don't update directory access times

                  # SSD optimizations
                  "discard"           # Enable TRIM support

                  # XFS-specific optimizations
                  "logbufs=8"         # More log buffers for better performance
                  "logbsize=256k"     # Larger log buffer size
                  "largeio"           # Optimize for large I/O operations (games)
                  "swalloc"           # Stripe-width allocation (better for sequential)
                ];
              };
            };
          };
        };
      };
    };

    # tmpfs root for impermanence (ephemeral system state)
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [
          "defaults"
          "size=2G"           # 2GB tmpfs (adequate for system)
          "mode=755"
        ];
      };
    };
  };
}

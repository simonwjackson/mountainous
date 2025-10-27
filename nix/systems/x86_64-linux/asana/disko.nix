{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";  # Fixed: was /dev/sda, now correct NVMe device
        content = {
          type = "gpt";
          partitions = {
            # EFI boot partition
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "umask=0077"  # Secure boot partition
                ];
              };
            };

            # Swap partition (20GB for hibernate support with 16GB RAM)
            swap = {
              size = "20G";
              label = "swap";
              content = {
                type = "swap";
                resumeDevice = true;  # Enable hibernate resume
              };
            };

            # LUKS2 encrypted root partition (rest of disk)
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "asana-root";  # LUKS device name

                # LUKS2 settings for better security and performance
                settings = {
                  # Use LUKS2 format
                  type = "luks2";

                  # Use strong encryption (AES-XTS with 512-bit key)
                  cipher = "aes-xts-plain64";
                  keySize = 512;

                  # Use Argon2id for key derivation (more secure than PBKDF2)
                  # Note: Requires LUKS2 format
                  pbkdfAlgo = "argon2id";

                  # Allow discards for SSD TRIM support
                  allowDiscards = true;
                };

                # Btrfs filesystem inside LUKS
                content = {
                  type = "btrfs";
                  extraArgs = ["-f"];  # Force if needed

                  # Btrfs subvolumes for impermanence
                  subvolumes = {
                    # Root subvolume (ephemeral - wiped on boot with impermanence)
                    "@root" = {
                      mountpoint = "/";
                      mountOptions = [
                        "compress=zstd"      # Enable compression
                        "noatime"            # Don't update access times (SSD optimization)
                        "nodiratime"         # Don't update directory access times
                        "discard=async"      # Async TRIM for SSD
                        "space_cache=v2"     # Use space cache v2
                      ];
                    };

                    # Nix store subvolume (persistent)
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

                    # Persistent data subvolume (survives reboots)
                    "@persist" = {
                      mountpoint = "/tundra/permafrost";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                        "nodiratime"
                        "discard=async"
                        "space_cache=v2"
                      ];
                    };

                    # System logs subvolume (persistent)
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

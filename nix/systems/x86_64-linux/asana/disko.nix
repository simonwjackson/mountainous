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

                # LUKS2 settings
                # Note: Disko's luks type uses cryptsetup defaults (LUKS2, aes-xts-plain64, argon2id)
                settings = {
                  # Allow discards for SSD TRIM support
                  allowDiscards = true;
                };

                # Btrfs filesystem inside LUKS
                content = {
                  type = "btrfs";
                  extraArgs = ["-f"];  # Force if needed

                  # Btrfs subvolumes for persistent storage
                  # Following frostbite pattern: separate subvolumes for /nix and /var/log
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
  };
}

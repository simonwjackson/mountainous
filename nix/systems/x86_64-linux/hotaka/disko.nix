{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
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
                  "umask=0077" # Secure boot partition
                ];
              };
            };

            # Swap partition (20GB for hibernate support with 16GB RAM)
            swap = {
              size = "20G";
              content = {
                type = "swap";
                resumeDevice = true; # Enable hibernate resume
              };
            };

            # Root partition with Btrfs (rest of disk)
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"]; # Force if needed

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
}

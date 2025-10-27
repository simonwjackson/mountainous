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

            # LUKS2 encrypted partition for persistent storage
            # Note: Root (/) is tmpfs defined in default.nix
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "asana-persist";  # LUKS device name for persistent storage

                # Ext4 filesystem for persistent storage
                # Using ext4 for simplicity and reliability
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/tundra/permafrost";
                  mountOptions = [
                    "noatime"           # Don't update access times (SSD optimization)
                    "nodiratime"        # Don't update directory access times
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}

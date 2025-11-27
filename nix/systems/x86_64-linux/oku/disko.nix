{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # Huawei MateBook E 512GB NVMe
        device = "/dev/disk/by-id/nvme-PCIe-8_SSD_512GB_YMA1512JA214122LHB";
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
                  "umask=0077"
                ];
              };
            };

            # Swap partition (20GB for hibernate with 16GB RAM)
            swap = {
              size = "20G";
              content = {
                type = "swap";
                resumeDevice = true;
              };
            };

            # Root partition with Btrfs
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"];

                subvolumes = {
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

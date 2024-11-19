{ disks ? [ "/dev/vda" ], ... }: {
  disko.devices = {
    disk = {
      # Parity disks
      parity00 = {
        type = "disk";
        device = "/dev/disk-by-id/ata-WDC_WD80EFAX-68LHPN0_7SGKDA3C";
        content = {
          type = "gpt";
          partitions = {
            parity00 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/data/parity/00";
                mountOptions = [
                  "defaults"
                  "nofail"
                  "noatime"
                  "logbufs=8"
                ];
              };
            };
          };
        };
      };

      main = {
        type = "disk";
        device = "/dev/disk-by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4P4NF0M317686M_1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "512M";
              type = "EF00";
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
                extraArgs = ["-f"]; # Override existing partition
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                subvolumes = {
                  # Subvolume name is different from mountpoint
                  "/root" = {
                    mountpoint = "/";
                  };
                  # Subvolume name is the same as the mountpoint
                  "/var" = {
                    mountOptions = ["compress=zstd"];
                    mountpoint = "/var";
                  };
                  "/home" = {
                    mountOptions = ["compress=zstd"];
                    mountpoint = "/home";
                  };
                  "/nix" = {
                    mountOptions = ["compress=zstd" "noatime"];
                    mountpoint = "/nix";
                  };
                  # Subvolume for the swapfile
                  "/swap" = {
                    mountpoint = "/swap";
                    swap = {
                      swapfile.size = "64G";
                    };
                  };
                };

                mountpoint = "/root";
                swap = {
                  swapfile = {
                    size = "64G";
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

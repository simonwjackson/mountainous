{
  disko.devices = {
    disk = {
      # NVMe 1: primary ESP + btrfs member. The btrfs filesystem is created
      # from nvme1 below so both devices can be passed to mkfs.btrfs at once.
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-SAMSUNG_MZQLB7T6HMLA-00007_S4BGNC0R803650";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
                extraArgs = ["-n" "ESP"];
              };
            };
            swap = {
              size = "64G";
              content = {
                type = "swap";
                randomEncryption = false;
                resumeDevice = true;
                extraArgs = ["-L" "swap"];
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

      # NVMe 2: recovery ESP + native btrfs RAID0 spanning both NVMe drives.
      nvme1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-SAMSUNG_MZQLB7T6HMLA-00007_S4BGNC0RA01126";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                # Not mounted. systemd-boot install mirrors /boot here.
                extraArgs = ["-n" "ESP2"];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-d raid0"
                  "-m raid1"
                  "/dev/disk/by-id/nvme-SAMSUNG_MZQLB7T6HMLA-00007_S4BGNC0R803650-part3"
                ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = ["compress=zstd" "noatime" "space_cache=v2"];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = ["compress=zstd" "noatime" "space_cache=v2"];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = ["compress=zstd" "noatime" "space_cache=v2"];
                  };
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = ["compress=zstd" "noatime" "space_cache=v2"];
                  };
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = ["compress=zstd" "noatime" "space_cache=v2"];
                  };
                  "@games" = {
                    mountpoint = "/srv/games";
                    mountOptions = ["compress=zstd" "noatime" "space_cache=v2"];
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

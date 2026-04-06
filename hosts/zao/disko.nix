{
  disko.devices = {
    disk = {
      # SD card: boot only
      boot = {
        type = "disk";
        device = "/dev/disk/by-id/mmc-SD32G_0xfcf357fa";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/efi";
                mountOptions = ["umask=0077"];
                extraArgs = ["-n" "ESP"];
              };
            };
            boot = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
                extraArgs = ["-L" "boot"];
              };
            };
          };
        };
      };

      # NVMe 1: partition only — btrfs RAID created from nvme1
      # Alphabetically first so disko processes it before the RAID member.
      # No content inside: the btrfs mkfs on nvme1 pulls this partition in.
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800725";
        content = {
          type = "gpt";
          partitions = {
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

      # NVMe 2: creates the btrfs RAID 0 spanning both NVMe drives
      nvme1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800890";
        content = {
          type = "gpt";
          partitions = {
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-d raid0"
                  "/dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22343V800725-part1"
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
                };
              };
            };
          };
        };
      };
    };
  };
}

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-NVME_SSD_512GB_2208VC0S036H0498";
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
              size = "1G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
                extraArgs = ["-L" "boot"];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f" "-L" "root"];
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
                  "@swap" = {
                    mountpoint = "/swap";
                    mountOptions = ["noatime" "space_cache=v2"];
                  };
                };
              };
            };
          };
        };
      };
      # 2TB microSD card for Steam games
      sdcard = {
        type = "disk";
        device = "/dev/disk/by-id/mmc-00000_0x18070f0e";
        content = {
          type = "gpt";
          partitions = {
            games = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/media/tank";
                mountOptions = ["noatime" "errors=continue"];
                extraArgs = ["-L" "tank" "-O" "dir_index,extent,filetype,flex_bg,has_journal,large_file,metadata_csum,sparse_super2,uninit_bg"];
              };
            };
          };
        };
      };
    };
  };
}

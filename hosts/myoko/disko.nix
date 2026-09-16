# CAUTION: `nix run .#deploy` wipes whatever `device` names. The path below is
# the slot, not this machine's disk. Read the real identifier on the laptop
# (`ls -l /dev/disk/by-id/ | grep nvme`) and put it here before any deploy.
#
# Layout copied from yuki: ESP, a plain /boot, then LUKS over btrfs subvolumes.
# The @swap subvolume exists so hibernation can get a swapfile later.
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
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
                type = "luks";
                name = "cryptroot";
                settings.allowDiscards = true;
                extraFormatArgs = ["--label=cryptroot"];
                content = {
                  type = "btrfs";
                  extraArgs = ["-f"];
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
      };
    };
  };
}

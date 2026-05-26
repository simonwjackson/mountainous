{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["defaults" "umask=0077"];
              };
            };
            swap = {
              size = "8G";
              content = {
                type = "swap";
                resumeDevice = true;
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"];
                subvolumes = {
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = ["compress=zstd" "noatime" "nodiratime" "discard=async" "space_cache=v2"];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = ["compress=zstd" "noatime" "nodiratime" "discard=async" "space_cache=v2"];
                  };
                  "@permafrost" = {
                    mountpoint = "/tundra/permafrost";
                    mountOptions = ["compress=zstd" "noatime" "nodiratime" "discard=async" "space_cache=v2"];
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

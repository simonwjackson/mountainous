{
  disko.devices = {
    disk = {
      # Kingston SSD - SUV500M8240G 224GB
      main = {
        type = "disk";
        device = "/dev/disk/by-id/ata-KINGSTON_SUV500M8240G_50026B7683B6CE9D";
        content = {
          type = "gpt";
          partitions = {
            BOOT = {
              size = "1M";
              type = "EF02"; # GRUB MBR
            };
            ESP = {
              size = "2G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" "nodiratime" "discard=async" "space_cache=v2" ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "compress=zstd" "noatime" "nodiratime" "discard=async" "space_cache=v2" ];
                  };
                  "@permafrost" = {
                    mountpoint = "/tundra/permafrost";
                    mountOptions = [ "compress=zstd" "noatime" "nodiratime" "discard=async" "space_cache=v2" ];
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

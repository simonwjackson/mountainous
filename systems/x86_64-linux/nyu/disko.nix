{
  disko.devices = {
    disk = {
      nvme0n1 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "550M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0022"
                  "dmask=0022"
                ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"];
                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = ["compress=zstd:3" "discard=async" "space_cache=v2"];
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = ["compress=zstd:3" "discard=async" "space_cache=v2"];
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = ["compress=zstd:3" "noatime" "discard=async" "space_cache=v2"];
                  };
                  # "/snowscape" = {
                  #   mountpoint = "/snowscape";
                  #   mountOptions = ["compress=zstd:3" "discard=async" "space_cache=v2"];
                  # };
                };
              };
            };
          };
        };
      };
    };
  };
}

{...}: {
  disko.devices.disk = {
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
              };
            };
          };
        };
      };
    };
  };
}

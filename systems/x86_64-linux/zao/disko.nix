{
  disko.devices = {
    nodev = {
      "/" = {
        fsType = "xfs";
        mountOptions = ["defaults"];
        device = "/dev/md/raid0";
      };
      "/boot" = {
        fsType = "vfat";
        mountOptions = ["defaults"];
        device = "/dev/disk/by-partlabel/ESP";
      };
    };

    disk = {
      mmcblk0 = {
        type = "disk";
        device = "/dev/mmcblk0";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              label = "ESP";
              type = "EF00";
              size = "512M";
              content = {
                type = "filesystem";
                format = "vfat";
              };
            };
          };
        };
      };

      nvme0 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            raid = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "raid0";
              };
            };
          };
        };
      };

      nvme1 = {
        type = "disk";
        device = "/dev/nvme1n1";
        content = {
          type = "gpt";
          partitions = {
            raid = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "raid0";
              };
            };
          };
        };
      };
    };

    mdadm = {
      raid0 = {
        type = "mdadm";
        level = 0;
        metadata = "1.2";
        content = {
          type = "filesystem";
          format = "xfs";
        };
      };
    };
  };
}

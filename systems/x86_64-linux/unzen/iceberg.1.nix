{
  disko.devices = {
    disk = {
      "iceberg.1.00" = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST5000LM000-2AN170_WCJ5MNMY";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "iceberg.1";
              };
            };
          };
        };
      };
      "iceberg.1.01" = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST5000LM000-2AN170_WCJ5ST8D";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "iceberg.1";
              };
            };
          };
        };
      };
      "iceberg.1.02" = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST5000LM000-2AN170_WCJ5NH7N";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "iceberg.1";
              };
            };
          };
        };
      };
      "iceberg.1.03" = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST5000LM000-2AN170_WCJ5S7NK";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "iceberg.1";
              };
            };
          };
        };
      };
    };
    zpool = {
      "iceberg.1" = {
        type = "zpool";
        mode = "raidz2";
        options = {
          cachefile = "none";
          ashift = "12";
          autotrim = "off";
        };
        # Minimal root options since we'll configure via systemd
        rootFsOptions = {
          canmount = "noauto";
          mountpoint = "none";
        };
      };
    };
  };
}

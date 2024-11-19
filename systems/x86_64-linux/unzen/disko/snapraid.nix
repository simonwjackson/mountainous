{...}: {
  disko.devices.disk = {
    hdd00 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-WDC_WD80EFAX-68LHPN0_7SGKDA3C";
      content = {
        type = "gpt";
        partitions = {
          parity00 = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/data/parity/00";
              mountOptions = [
                "defaults"
                "nofail"
                "noatime"
                "logbufs=8"
              ];
            };
          };
        };
      };
    };

    hdd01 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-WDC_WD80EFBX-68AZZN0_VRJVWS3K";
      content = {
        type = "gpt";
        partitions = {
          parity01 = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/data/parity/00";
              mountOptions = [
                "defaults"
                "nofail"
                "noatime"
                "logbufs=8"
              ];
            };
          };
        };
      };
    };

    hdd02 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-WDC_WD80EDAZ-11TA3A0_VGH3KRAG";
      content = {
        type = "gpt";
        partitions = {
          tank00 = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/data/tank/00";
              mountOptions = [
                "defaults"
                "nofail"
                "noatime"
                "logbufs=8"
              ];
            };
          };
        };
      };
    };
  };
}

{lib, ...}: {
  # Shared configuration for iceberg array - contains NO operational logic
  # This is pure data configuration that can be safely shared between
  # mount operations (safe) and format operations (destructive)

  icebergArray = {
    # Disk definitions - shared between mount and format operations
    disks = [
      {
        id = "iceberg00";
        device = "/dev/disk/by-id/usb-TerraMas_TDAS_7SGKDA3C-0:0";
        partition = "1";
        # nofail + longer timeout: don't block boot, but give USB drives time to spin up
        mountOptions = ["defaults" "nofail" "noatime" "lazytime" "logbufs=8" "allocsize=1m" "x-systemd.device-timeout=90"];
      }
      {
        id = "iceberg01";
        device = "/dev/disk/by-id/usb-TerraMas_TDAS_VRJVWS3K-0:0";
        partition = "1";
        mountOptions = ["defaults" "nofail" "noatime" "lazytime" "logbufs=8" "allocsize=1m" "x-systemd.device-timeout=90"];
      }
      {
        id = "iceberg02";
        device = "/dev/disk/by-id/usb-TerraMas_TDAS_VGH3KRAG-0:0";
        partition = "1";
        mountOptions = ["defaults" "nofail" "noatime" "nodiratime" "lazytime" "logbufs=8" "allocsize=64m" "x-systemd.device-timeout=90"];
      }
      {
        id = "iceberg03";
        device = "/dev/disk/by-id/usb-TerraMas_TDAS_VGH13XMG-0:0";
        partition = "1";
        mountOptions = ["defaults" "nofail" "noatime" "nodiratime" "lazytime" "logbufs=8" "allocsize=64m" "x-systemd.device-timeout=90"];
      }
      {
        id = "iceberg04";
        device = "/dev/disk/by-id/usb-TerraMas_TDAS_WD-CA081PBK-0:0";
        partition = "1";
        mountOptions = ["defaults" "nofail" "noatime" "lazytime" "logbufs=8" "allocsize=1m" "x-systemd.device-timeout=90"];
      }
      {
        id = "iceberg05";
        device = "/dev/disk/by-id/usb-TerraMas_TDAS_7SGK9H0C-0:0";
        partition = "1";
        mountOptions = ["defaults" "nofail" "noatime" "lazytime" "logbufs=8" "allocsize=1m" "x-systemd.device-timeout=90"];
      }
    ];

    # Mount point structure - shared paths
    mountPoints = {
      disks = "/tundra/disks";
      merged = "/tundra/merged";
      pools = "/tundra/pools";
      groups = "/tundra/groups";
    };

    # Media user configuration - shared between modules
    media = {
      user = "media";
      uid = 333;
      group = "media";
      gid = 333;
    };

    # Disk categorization for SnapRAID (data vs parity)
    snapraid = {
      dataDisks = ["iceberg00" "iceberg01" "iceberg04" "iceberg05"];
      parityDisks = ["iceberg02" "iceberg03"];
    };

    # Helper function to generate mount point path for a disk
    getDiskMountPoint = mountPointsConfig: diskId: let
      diskNum = lib.strings.removePrefix "iceberg" diskId;
    in "${mountPointsConfig.disks}/iceberg/${diskNum}/0";

    # Helper function to get disk by ID
    getDisk = diskId: disks:
      lib.findFirst (disk: disk.id == diskId) null disks;
  };
}

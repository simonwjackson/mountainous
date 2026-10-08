# Initial install only. These two whole NVMe drives will be erased by Disko.
# The recovery USB and future card-mounted SSDs are deliberately absent.
let
  member = device: label: bootMount: {
    inherit device;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          priority = 1;
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = bootMount;
            mountOptions = [ "umask=0077" ];
          };
        };
        pool = {
          size = "100%";
          priority = 2;
          content = {
            type = "bcachefs";
            filesystem = "unzen";
            inherit label;
            extraFormatArgs = [ "--failure_domain=${label}" ];
          };
        };
      };
    };
  };
  subvolume = mountpoint: {
    inherit mountpoint;
    mountOptions = [ "noatime" ];
  };
in
{
  # Boot files consume fixed ESP space; cap retained boot generations.
  boot.loader.systemd-boot.configurationLimit = 5;
  services.bcachefs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
    interval = "monthly";
  };

  disko.devices = {
    disk = {
      unzen-kioxia =
        member "/dev/disk/by-id/nvme-KXG60ZNV1T02_NVMe_KIOXIA_1024GB_81UFC0UWF8T3" "onboard.kioxia"
          "/boot";
      # Reserve an ESP now so a second boot copy does not need repartitioning.
      # It is formatted but not mounted or populated by systemd-boot.
      unzen-sn770 = member "/dev/disk/by-id/nvme-WD_BLACK_SN770_1TB_22135C800678" "onboard.sn770" null;
    };
    bcachefs_filesystems.unzen = {
      type = "bcachefs_filesystem";
      passwordFile = null;
      extraFormatArgs = [
        "--data_replicas=2"
        "--metadata_replicas=2"
      ];
      # Subvolumes organize files and snapshots; none has a fixed allocation.
      subvolumes = {
        "subvolumes/root" = subvolume "/";
        "subvolumes/home" = subvolume "/home";
        "subvolumes/nix" = subvolume "/nix";
        "subvolumes/data" = subvolume "/srv";
      };
    };
  };
}

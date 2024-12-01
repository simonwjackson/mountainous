{...}: let
  diskBase = "/avalanche/disks/";
  owner = "media";
  uid = "333";
  group = "media";
  gid = "333";
in {
  disko.devices.disk = {
    iceberg00 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-WDC_WD80EFAX-68LHPN0_7SGKDA3C";
      content = {
        type = "gpt";
        partitions = {
          "iceberg00.0" = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/avalanche/disks/iceberg/00/0";
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

    iceberg01 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-WDC_WD80EFBX-68AZZN0_VRJVWS3K";
      content = {
        type = "gpt";
        partitions = {
          "iceberg01.0" = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/avalanche/disks/iceberg/01/0";
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

    iceberg02 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-WDC_WD80EDAZ-11TA3A0_VGH3KRAG";
      content = {
        type = "gpt";
        partitions = {
          "iceberg02.0" = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/avalanche/disks/iceberg/02/0";
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

    iceberg03 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-WDC_WD80EDAZ-11TA3A0_VGH13XMG";
      content = {
        type = "gpt";
        partitions = {
          "iceberg02.0" = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/avalanche/disks/iceberg/03/0";
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

    iceberg04 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-WDC_WD80EMZZ-11B4FB0_WD-CA081PBK";

      content = {
        type = "gpt";
        partitions = {
          "iceberg02.0" = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/avalanche/disks/iceberg/04/0";
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

    iceberg05 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-WDC_WD80EFAX-68LHPN0_7SGK9H0C";
      content = {
        type = "gpt";
        partitions = {
          "iceberg02.0" = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/avalanche/disks/iceberg/05/0";
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

    blizzard01 = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-WD_BLACK_SN770_1TB_22135C800678";
      content = {
        type = "gpt";
        partitions = {
          "blizzard01.0" = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "f2fs";
              mountpoint = "/avalanche/disks/blizzard/01/0";
              mountOptions = [
                "compress_algorithm=zstd" # Use ZSTD compression
                "compress_chksum" # Enable checksum for compressed data
                "atgc" # Enable age-threshold garbage collection
                "gc_merge" # Merge segments during garbage collection
                "lazytime" # Delayed inode timestamps for better performance
                "noatime" # Don't update access times
                "nodiratime" # Don't update directory access times
                "discard" # Enable TRIM/discard support for SSD
              ];
            };
          };
        };
      };
    };

    blizzard02 = let
      mountpoint = "${diskBase}/blizzard/02/0";
    in {
      type = "disk";
      device = "/dev/disk/by-id/nvme-SAMSUNG_MZQLB7T6HMLA-00007_S4BGNC0R803650";
      content = {
        type = "gpt";
        partitions = {
          "blizzard02.0" = {
            size = "100%";
            content = {
              inherit mountpoint;
              type = "filesystem";
              format = "xfs";
              mountOptions = [
                "defaults"
                "nofail"
                "noatime"
                "logbufs=8"
                "allocsize=1m" # Optimized for large files
                "largeio" # Enable larger I/O sizes
                "inode64" # Enable large inode numbers
                "swalloc" # Enable stripe-width allocation
              ];
            };
          };
        };
      };
    };
  };

  # systemd.services.configure-snowscape = {
  #   description = "Configure Snowscape directory permissions";
  #   wantedBy = ["multi-user.target"];
  #   after = ["local-fs.target"];
  #   script = let
  #     snowscape = "${diskBase}/blizzard/02/0/snowscape";
  #   in ''
  #     # Create directory with correct permissions in one go
  #     ${pkgs.coreutils}/bin/install -d -o ${owner} -g ${group} -m 3775 ${snowscape}
  #
  #     # Set ACLs for directories to include sticky bit
  #     ${pkgs.acl}/bin/setfacl -R -d -m u:${owner}:rwx,d:u:${owner}:rwx ${snowscape}
  #     ${pkgs.acl}/bin/setfacl -R -d -m g:${group}:rwx,d:g:${group}:rwx ${snowscape}
  #
  #     # Find all existing directories and set permissions
  #     ${pkgs.findutils}/bin/find ${snowscape} -type d -exec ${pkgs.coreutils}/bin/install -d -o ${owner} -g ${group} -m 3775 {} \;
  #
  #     # Monitor for new directories
  #     # ${pkgs.inotify-tools}/bin/inotifywait -m -r -e create ${snowscape} | while read path action file; do
  #     #   if [ -d "$path/$file" ]; then
  #     #     ${pkgs.coreutils}/bin/install -d -o ${owner} -g ${group} -m 3775 "$path/$file"
  #     #     ${pkgs.acl}/bin/setfacl -d -m u:${owner}:rwx,d:u:${owner}:rwx "$path/$file"
  #     #     ${pkgs.acl}/bin/setfacl -d -m g:${group}:rwx,d:g:${group}:rwx "$path/$file"
  #     #   fi
  #     # done &
  #   '';
  #   serviceConfig = {
  #     Type = "simple";
  #     Restart = "always";
  #     RestartSec = "10";
  #   };
  # };

  # systemd.paths.monitor-snowscape = {
  #   wantedBy = ["multi-user.target"];
  #   pathConfig = {
  #     PathModified = "${diskBase}/blizzard/02/0/snowscape";
  #     Unit = "configure-snowscape.service";
  #   };
  # };
}

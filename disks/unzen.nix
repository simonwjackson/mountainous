# Initial install only. These two whole NVMe drives will be erased by Disko.
# The recovery USB and future card-mounted SSDs are deliberately absent.
{ lib, ... }:
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
            # An absent ESP must not block boot from the surviving drive.
            mountOptions = [
              "umask=0077"
              "nofail"
            ];
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
    # Permit reduced redundancy, not the data-loss override degraded=very.
    mountOptions = [
      "noatime"
      "degraded=yes"
    ];
  };
in
{
  boot.loader = {
    systemd-boot.enable = false;
    # Each ESP gets EFI/BOOT/BOOTX64.EFI, without depending on an NVRAM entry.
    efi.canTouchEfiVariables = false;
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      # GRUB reads only FAT32 boot files, never the bcachefs root/store.
      copyKernels = true;
      configurationLimit = 5;
      devices = lib.mkForce [ ];
      mirroredBoots = [
        {
          path = "/boot";
          devices = [ "nodev" ];
        }
        {
          path = "/boot-secondary";
          devices = [ "nodev" ];
        }
      ];
    };
  };
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
      unzen-sn770 =
        member "/dev/disk/by-id/nvme-WD_BLACK_SN770_1TB_22135C800678" "onboard.sn770"
          "/boot-secondary";
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

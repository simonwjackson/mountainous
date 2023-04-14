{ config, lib, pkgs, modulesPath, ... }: {
  boot.initrd.services.swraid.enable = true;
  boot.initrd.services.swraid.mdadmConf=''
    DEVICE /dev/nvme0n1p1 /dev/nvme1n1p1
    ARRAY /dev/md/blizzard metadata=1.2 name=nixos:blizzard UUID=24a90e7c:fc627772:1f7242f2:746ecbfc
  '';

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/428963f5-9490-4996-bd6e-df2466f77999";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/8A39-D14C";
      fsType = "vfat";
    };

  fileSystems."/var" =
    { device = "/dev/disk/by-uuid/b28e405c-23d9-426c-82a6-1391191f4cee";
      fsType = "ext4";
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/5fd65d8f-f0a6-4c7d-90f7-e4be97cfe384";
      fsType = "xfs";
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/9dfbb7ff-a238-40c9-9bd6-797b3d1297b4";
      fsType = "xfs";
    };

  fileSystems."/storage" =
    { device = "/dev/disk/by-uuid/9bed3725-d75e-4900-9ff7-bfad503b1e57";
      fsType = "xfs";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/79bc5677-6ac7-45d9-b72c-c6b9c5093ef4"; }
    ];
}

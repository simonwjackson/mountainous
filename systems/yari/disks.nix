{ config, lib, pkgs, modulesPath, ... }: {
  fileSystems."/" =
    { device = "/dev/nvme0n1p2";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" ];
    };

  fileSystems."/home" =
    { device = "/dev/nvme0n1p2";
      fsType = "btrfs";
      options = [ "subvol=home" "compress=zstd" "noatime" ];
    };

  fileSystems."/nix" =
    { device = "/dev/nvme0n1p2";
      fsType = "btrfs";
      options = [ "subvol=nix" "compress=zstd" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/ED99-9177";
      fsType = "vfat";
    };

  # fileSystems."/storage" =
  #   { device = "/dev/disk/by-uuid/905b4626-9364-477c-bdb7-0275d520ce31";
  #     fsType = "btrfs";
  #     options = [ "subvol=storage" "compress=zstd" ];
  #   };
  # 
  #   fileSystems."/home/simonwjackson/.local/share/Steam/steamapps" = {
  #     device = "/storage/gaming/games/steam";
  #     options = [ "bind" ];
  #   };
  #
  # fileSystems."/swap" =
  #   { device = "/dev/disk/by-uuid/905b4626-9364-477c-bdb7-0275d520ce31";
  #     fsType = "btrfs";
  #     options = [ "subvol=swap" "noatime" ];
  #   };

  # swapDevices = [ { device = "/swap/swapfile"; } ];
}

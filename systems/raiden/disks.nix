{ config, lib, pkgs, modulesPath, ... }: {
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/905b4626-9364-477c-bdb7-0275d520ce31";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/905b4626-9364-477c-bdb7-0275d520ce31";
      fsType = "btrfs";
      options = [ "subvol=nix" "noatime" "compress=zstd" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/905b4626-9364-477c-bdb7-0275d520ce31";
      fsType = "btrfs";
      options = [ "subvol=home" "compress=zstd" ];
    };

  fileSystems."/storage" =
    { device = "/dev/disk/by-uuid/905b4626-9364-477c-bdb7-0275d520ce31";
      fsType = "btrfs";
      options = [ "subvol=storage" "compress=zstd" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/1EB1-8B0E";
      fsType = "vfat";
    };
    fileSystems."/home/simonwjackson/.local/share/Steam/steamapps" = {
      device = "/storage/gaming/games/steam";
      options = [ "bind" ];
    };

  # fileSystems."/swap" =
  #   { device = "/dev/disk/by-uuid/905b4626-9364-477c-bdb7-0275d520ce31";
  #     fsType = "btrfs";
  #     options = [ "subvol=swap" "noatime" ];
  #   };

  # swapDevices = [ { device = "/swap/swapfile"; } ];
}

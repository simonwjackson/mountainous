{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}: let
  inherit (lib.backpacker) enabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  backpacker = {
    performance = enabled;
    gaming = {
      core = enabled;
      emulation = {
        enable = true;
        gen-7 = true;
        gen-8 = true;
        gamingDir = "/glacier/snowscape/gaming";
        saves = "/glacier/blizzard/gaming/profiles/simonwjackson/progress/saves";
      };
      steam = enabled;
    };
    networking.core.names = [
      {
        name = "wifi";
        mac = "e4:60:17:d1:e6:d8";
      }
    ];
    profiles.laptop = enabled;
    syncthing = {
      key = config.age.secrets.kita-syncthing-key.path;
      cert = config.age.secrets.kita-syncthing-cert.path;
    };
    waydriod = enabled;
    hardware = {
      bluetooth = enabled;
    };
    desktops.plasma = enabled;
  };

  mountainous = {
    hardware = {
      devices.gpd-win-mini = enabled;
    };
  };

  # HACK: mergerfs mount appears to be broken
  fileSystems."/glacier/snowscape" = {
    device = "/glacier/blizzard";
    options = ["bind"];
  };

  # fileSystems."/glacier/snowscape" = {
  #   # depends = ["/glacier/blizzard" "/glacier/sleet"];
  #   depends = ["/glacier/blizzard"];
  #   device = "/glacier/blizzard";
  #   # device = "/glacier/blizzard:/glacier/sleet";
  #   fsType = "fuse.mergerfs";
  #   options = [
  #     "minfreespace=1G"
  #     "category.create=ff"
  #     "category.search=ff"
  #     "attr_timeout=60"
  #     "ignorepponrename=true"
  #     "moveonenospc=true"
  #   ];
  # };

  fileSystems."/glacier/sleet" = {
    device = "/dev/disk/by-label/sleet";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/5067-7886";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/3873bb31-f29c-4a3b-98f9-10f2334c55a8";
    }
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=root" "discard=async" "compress=zstd"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=home" "discard=async" "compress=zstd"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=nix" "compress=zstd" "discard=async" "noatime"];
  };

  fileSystems."/glacier/blizzard" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=blizzard" "discard=async" "compress=zstd"];
  };

  # WARN: Do not change this unless reinstalling
  system.stateVersion = "23.11";
}

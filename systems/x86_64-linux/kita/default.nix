{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  inherit (lib.mountainous) enabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./sunshine.nix
  ];

  services.syncthing-auto-pause = {
    enable = true;
    managedShares = [
      "games"
      "videos"
    ];
  };

  mountainous = {
    desktops.hyprland = {
      enable = true;
      autoLogin = true;
    };
    desktops.hyprlandControl = enabled;
    services.gamescope-reaper.duration = 20;
    gaming = {
      core = enabled;
      emulation = {
        enable = true;
        gamingDir = "/snowscape/gaming";
        gen-7 = true;
        gen-8 = true;
        saves = "/snowscape/gaming/profiles/simonwjackson/progress/saves";
      };
      steam = enabled;
    };
    hardware = {
      bluetooth = enabled;
      devices.gpd-win-mini = enabled;
    };
    networking.core.names = [
      {
        name = "wifi";
        mac = "e4:60:17:d1:e6:d8";
      }
    ];
    performance = enabled;
    profiles.laptop = enabled;
    syncthing = {
      key = config.age.secrets.kita-syncthing-key.path;
      cert = config.age.secrets.kita-syncthing-cert.path;
    };
  };

  environment.systemPackages = [pkgs.mergerfs];

  fileSystems."/snowscape" = {
    device = "/storage/blizzard:/storage/sleet";
    fsType = "fuse.mergerfs";
    options = [
      "minfreespace=4G"
      "use_ino"
      "cache.files=partial"
      "dropcacheonclose=true"
      "allow_other"
      "category.create=ff"
      "fsname=snowscape"
      "nonempty"
      "defaults"
      "allow_other"
    ];
    noCheck = true;
  };

  fileSystems."/glacier" = {
    device = "/snowscape:/net/aka/nfs/snowscape";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "cache.files=off"
      "dropcacheonclose=true"
      "category.create=mfs"
      "minfreespace=4G"
      "fsname=glacier"
      "async_read=false"
    ];
    noCheck = true;
  };

  fileSystems."/storage/sleet" = {
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

  fileSystems."/storage/blizzard" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=blizzard" "discard=async" "compress=zstd"];
  };

  # WARN: Do not change this unless reinstalling
  system.stateVersion = "23.11";
}

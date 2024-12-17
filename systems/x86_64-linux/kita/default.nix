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

  mountainous = {
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
      bluetooth.device = "E4:60:17:D1:E6:DC";
      devices.gpd-win-mini = enabled;
    };
    networking.core.names = [
      {
        name = "wifi";
        mac = "e4:60:17:d1:e6:d8";
      }
    ];
    profiles = {
      laptop = enabled;
      workstation = enabled;
    };
    syncthing = {
      key = config.age.secrets.kita-syncthing-key.path;
      cert = config.age.secrets.kita-syncthing-cert.path;
    };
    snowscape = {
      enable = true;
      glacier = "unzen";
      paths = [
        "/avalanche/volumes/blizzard"
        "/avalanche/disks/sleet/0/00"
      ];
    };
  };

  fileSystems."/avalanche/disks/sleet/0/00" = {
    device = "/dev/disk/by-label/sleet";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/5067-7886";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

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

  fileSystems."/avalanche/volumes/blizzard" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=blizzard" "discard=async" "compress=zstd"];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/3873bb31-f29c-4a3b-98f9-10f2334c55a8";
    }
  ];

  # WARN: Do not change this unless reinstalling
  system.stateVersion = "23.11";
}

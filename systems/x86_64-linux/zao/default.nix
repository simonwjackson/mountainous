{
  config,
  pkgs,
  inputs,
  lib,
  modulesPath,
  ...
}: let
  inherit (lib.mountainous) enabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  mountainous = {
    hardware.devices.dell-9710 = enabled;
  };

  backpacker = {
    desktop.plasma = enabled;
    gaming = {
      core = {
        enable = true;
        isHost = true;
      };
      emulation = {
        enable = true;
        gen-7 = true;
        gen-8 = true;
      };
      steam = enabled;
    };
    performance = enabled;
    networking.core.names = [
      {
        name = "wifi";
        mac = "ac:74:b1:8a:db:ee";
      }
    ];
    syncthing = {
      key = config.age.secrets.fiji-syncthing-key.path;
      cert = config.age.secrets.fiji-syncthing-cert.path;
    };
  };

  environment.systemPackages = with pkgs; [
    nfs-utils
    cifs-utils
  ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
      fsType = "btrfs";
      options = ["ssd" "subvol=root" "compress=zstd"];
    };

    "/home" = {
      device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
      fsType = "btrfs";
      options = ["ssd" "subvol=home" "compress=zstd"];
    };

    "/glacier/snowscape" = {
      device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
      fsType = "btrfs";
      options = ["ssd" "subvol=storage" "compress=zstd"];
    };

    "/nix" = {
      device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
      fsType = "btrfs";
      options = ["ssd" "subvol=nix" "compress=zstd" "noatime"];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/D21E-0411";
      fsType = "vfat";
    };
  };

  swapDevices = [{device = "/dev/nvme0n1p2";}];

  system.stateVersion = "23.05"; # Did you read the comment?
}

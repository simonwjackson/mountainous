{
  modulesPath,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled disabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd.luks.devices."crypted" = lib.mkForce {
      device = "/dev/disk/by-uuid/b688fe42-16eb-49f7-a9c9-c3a4210288e1";
      preLVM = true;
      allowDiscards = true;
    };
  };

  mountainous = {
    boot = enabled;
    gaming = {
      core = enabled;
      steam = enabled;
    };
    hardware = {
      bluetooth.device = "D4:D8:53:90:2B:70";
      devices.samsung-galaxy-book3-360 = enabled;
    };
    impermanence = enabled;
    networking.core.names = [
      {
        name = "wifi";
        mac = "d4:d8:53:90:2b:6c";
      }
    ];
    profiles = {
      laptop = enabled;
      workspace = disabled;
      workstation = enabled;
    };
    snowscape = {
      enable = true;
      glacier = "unzen";
      paths = [
        "/avalanche/volumes/blizzard"
        "/avalanche/disks/sleet/0/00"
      ];
    };
    syncthing = {
      key = config.age.secrets.fuji-syncthing-key.path;
      cert = config.age.secrets.fuji-syncthing-cert.path;
    };
  };

  system.stateVersion = "24.11";
}

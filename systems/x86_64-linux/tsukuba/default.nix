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
    (import ./disko.nix {
      device = "/dev/vda";
    })
  ];

  facter.reportPath = ./facter.json;

  boot = {
    kernelModules = [
      "nvme"
      "ahci" # SATA
    ];
    loader = {
      grub = {
        enable = true;
      };
    };
  };

  mountainous = {
    boot = disabled;
    profiles = {
      base = enabled;
      laptop = disabled;
      workstation = disabled;
    };
    # TODO: encrypt generated syncthing keys
    syncthing = {
      # key = config.age.secrets.tsukuba-syncthing-key.path;
      # cert = config.age.secrets.tsukuba-syncthing-cert.path;
    };
  };

  system.stateVersion = "24.11";
}

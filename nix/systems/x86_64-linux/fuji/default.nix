{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled;
in {
  imports = [
    ./x1-fold.nix # X1 Fold hardware-specific configuration
  ];

  # System services
  security.rtkit.enable = true;

  # Mountainous configuration
  mountainous = {
    agenix.enable = true;
    sound.enable = true;

    # Boot configuration
    boot.systemd-boot.enable = true;

    # Syncthing disabled as requested
    syncthing = {
      enable = false;
      key = "/run/agenix/fuji-syncthing-key";
      cert = "/run/agenix/fuji-syncthing-cert";
      systemsDir = ../../../../nix/systems;
    };

    # System profiles
    profiles = {
      base.enable = true;
      laptop.enable = true;
      workspace.enable = true;
      gaming.enable = true;
    };

    # Disk configuration
    disks = {
      frostbite = {
        enable = true;
        device = "/dev/nvme0n1";
        swapSize = "16G";
        encrypt = false;
      };
    };
  };

  # Bind mount for development workspace
  fileSystems."/snowscape" = {
    device = "/tundra/frostbite/snowscape";
    fsType = "none";
    options = ["bind"];
    neededForBoot = false;
  };

  system.stateVersion = "24.11";
}

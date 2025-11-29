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

  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but sometimes works better for legacy GPUs)
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # System services
  security.rtkit.enable = true;

  # Mountainous configuration
  mountainous = {
    agenix.enable = true;
    sound.enable = true;

    # Boot configuration
    boot.systemd-boot.enable = true;

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

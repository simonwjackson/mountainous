{
  config,
  lib,
  pkgs,
  hyprdynamicmonitors,
  ...
}: let
  syncthingShares = import ./syncthing-shares.nix;
  syncthingFolders =
    lib.mapAttrs (
      name: hostCfg: let
        shareCfg = import (../../home/simonwjackson/syncthing + "/${name}.nix");
      in
        assert (shareCfg.name or name) == name;
          (builtins.removeAttrs shareCfg ["name"]) // hostCfg
    )
    syncthingShares;
in {
  imports = [
    ./hardware.nix
    ./disko.nix
    ./quirks.nix
    ../../modules/nixos/device
    ../../features/gaming/nixos.nix
  ];

  home-manager.users.simonwjackson = {
    imports = [
      ../../features/gaming/home.nix
      hyprdynamicmonitors.homeManagerModules.default
    ];

    home.packages = [pkgs.lazygit];
  };

  networking.hostName = "yuki";

  mountainous = {
    presets = {
      core.enable = true;
      desktop.enable = true;
      portable.enable = true;
    };

    features = {
      firefox = {
        enable = true;
        cascade.enable = true;
      };
      bluetooth.enable = true;
      keyboard.enable = true;
    };
  };

  mountainous.features.syncthing = {
    enable = true;
    folders = syncthingFolders;
  };
  time.timeZone = "America/Denver";

  mountainous.device = {
    role = "portable";
    capabilities = {
      battery = true;
      formFactor = "laptop";
      touchscreen = false;
    };
  };

  services = {
    geoclue2 = {
      enable = true;
      enableDemoAgent = true;
      geoProviderUrl = "https://api.beacondb.net/v1/geolocate";
      submissionUrl = "https://api.beacondb.net/v2/geosubmit";
      appConfig = {
        automatic-timezoned = {
          isAllowed = true;
          isSystem = true;
          users = [];
        };
        gammastep = {
          isAllowed = true;
          isSystem = false;
          users = [];
        };
      };
    };

    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
    };

    timesyncd.enable = lib.mkDefault true;
  };

  nixpkgs.config.allowUnfree = true;

  mountainous.gaming.enable = true;

  users.users.simonwjackson.extraGroups = [
    "networkmanager"
    "video"
  ];

  boot = {
    # Arrow Lake-H suspend-to-idle support requires Linux 6.15 or newer.
    kernelPackages = pkgs.linuxPackages_latest;
  };

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 20480;
    }
  ];

  # gaming module enables graphics, pipewire, and rtkit
  # just add the 32-bit extras for native 32-bit apps
  hardware.graphics.enable32Bit = true;

  services.xserver.videoDrivers = ["modesetting"];

  system.stateVersion = "24.11";
}

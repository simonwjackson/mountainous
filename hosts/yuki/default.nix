{
  config,
  lib,
  pkgs,
  hyprdynamicmonitors,
  ...
}: {
  imports = [
    ./hardware.nix
    ./disko.nix
    ./quirks.nix
    ./lid-suspend.nix
    ../../modules/nixos/device
  ];

  home-manager = {
    users = {
      simonwjackson = {
        imports = [
          hyprdynamicmonitors.homeManagerModules.default
        ];

        home = {
          packages = [pkgs.lazygit];
        };
      };
    };
  };

  networking = {
    hostName = "yuki";
  };

  mountainous = {
    presets = {
      core.enable = true;
      workstation.enable = true;
      desktop.enable = true;
      portable.enable = true;
    };

    features = {
      firefox = {
        enable = true;
        cascade.enable = true;
      };
      bluetooth.enable = true;
      hibernation = {
        enable = true;
        resumeDevice = "/dev/mapper/cryptroot";
        swap = {
          mode = "swapfile-btrfs";
          path = "/swap/swapfile";
        };
      };
      keyboard.enable = true;
    };

    device = {
      role = "portable";
      capabilities = {
        battery = true;
        formFactor = "laptop";
        touchscreen = false;
      };
    };

    features.gaming.enable = true;
  };

  time = {
    timeZone = "America/Denver";
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

    timesyncd.enable = lib.mkDefault true;

    xserver = {
      videoDrivers = ["modesetting"];
    };
  };

  users = {
    users = {
      simonwjackson = {
        extraGroups = [
          "networkmanager"
          "video"
        ];
      };
    };
  };

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
  hardware = {
    graphics = {
      enable32Bit = true;
    };
  };

  system = {
    stateVersion = "24.11";
  };
}

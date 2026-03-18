{
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

  networking.hostName = "yuki";
  time.timeZone = "America/Denver";

  mountainous = {
    presets = {
      core.enable = true;
      desktop.enable = true;
      portable.enable = true;
      workstation.enable = true;
    };

    features = {
      # ── Networking ───────────────────────────────────────────────────
      device = {
        role = "portable";
        capabilities = {
          battery = true;
          formFactor = "laptop";
          touchscreen = false;
        };
      };

      # ── Services ─────────────────────────────────────────────────────
      hibernation = {
        enable = true;
        resumeDevice = "/dev/mapper/cryptroot";
        swap = {
          mode = "swapfile-btrfs";
          path = "/swap/swapfile";
        };
      };

      # ── User tools ──────────────────────────────────────────────────
      bluetooth.enable = true;
      firefox = {
        enable = true;
        cascade.enable = true;
      };
      gaming.enable = true;
      keyboard.enable = false;
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

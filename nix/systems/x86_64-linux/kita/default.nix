{
  config,
  pkgs,
  ...
}: {
  ###################
  # Mountainous
  ###################

  mountainous = {
    profiles = {
      base = {
        enable = true;
      };
    };
    # networking.core.names = [
    #   # TODO: Move to caldigit module
    #   {
    #     name = "eth";
    #     mac = "64:4b:f0:6a:6c:7e";
    #   }
    #   {
    #     name = "wifi";
    #     mac = "86:4f:69:77:9c:62";
    #   }
    # ];
    hardware = {
      devices = {
        gpd-win-mini = {
          enable = true;
        };
      };
    };
    disks = {
      frostbite = {
        enable = true;
        encrypt = true;
        device = "/dev/nvme0n1";
        swapSize = "32G";
      };
    };
    impermanence = {
      enable = true;
      persistPath = "/tundra/permafrost";
    };
    hyprland = {
      enable = true;
      autoLogin = true;
    };
    gaming = {
      core.enable = true;
      emulation = {
        enable = true;
        gen-7 = true;
        gen-8 = true;
      };
      steam.enable = true;
    };
  };

  ###################
  # Misc
  ###################

  # Basic system configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network configuration
  networking = {
    hostName = "kita"; # Define your hostname
  };

  # Basic packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    ex
  ];

  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  # User configuration
  users.users.simonwjackson = {
    initialPassword = "asdfasdfasdf";
  };

  services.hardware.bolt.enable = true; # Enable Thunderbolt support
  boot.kernelModules = [
    "igc"
    "thunderbolt"
  ];

  # This is required for NixOS
  system.stateVersion = "24.11";
}

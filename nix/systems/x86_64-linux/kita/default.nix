{pkgs, ...}: {
  # Basic system configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network configuration
  networking = {
    hostName = "kita"; # Define your hostname
    networkmanager.enable = true;
  };

  # Time zone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Basic packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    ex
  ];

  # Enable SSH
  services.openssh.enable = true;

  # User configuration
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    initialPassword = "asdfasdfasdf";
  };

  services.hardware.bolt.enable = true;  # Enable Thunderbolt support
  boot.kernelModules = [ "igc" "thunderbolt" ];

  # Enable flakes
  nix.settings.experimental-features = ["nix-command" "flakes"];

  mountainous = {
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

  # This is required for NixOS
  system.stateVersion = "24.11";
}

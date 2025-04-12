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
  };

  # This is required for NixOS
  system.stateVersion = "24.11";
}

{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./disko.nix
  ];

  # Boot configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Enable base profile
  mountainous = {
    profiles.base.enable = true;
  };

  # Networking
  networking.hostName = "asana";
  networking.networkmanager.enable = true;

  # Timezone
  time.timeZone = "UTC";

  # User configuration
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
  };

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Minimal packages
  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  # Enable flakes
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
  };

  system.stateVersion = "24.05";
}

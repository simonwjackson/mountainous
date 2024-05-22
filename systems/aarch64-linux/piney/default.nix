{
  lib,
  pkgs,
  inputs,
  system,
  target,
  format,
  virtual,
  systems,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  programs.icho = {
    enable = true;
  };

  mountainous.networking.zerotierone.enable = false;
  mountainous.networking.tailscaled.isMobileNixos = true;

  programs.mosh.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
    };
  };
  networking.hostName = "piney";

  #
  # Opinionated defaults
  #

  # Use Network Manager
  networking.wireless.enable = false;
  networking.networkmanager.enable = true;

  # Use PulseAudio
  # hardware.pulseaudio.enable = true;

  # Enable Bluetooth
  hardware.bluetooth.enable = true;

  # Enable power management options
  powerManagement.enable = true;

  # It's recommended to keep enabled on these constrained devices
  zramSwap.enable = true;

  # Auto-login for phosh
  services.xserver.desktopManager.phosh = {
    user = "simonwjackson";
  };

  #
  # User configuration
  #

  users.users."simonwjackson" = {
    isNormalUser = true;
    description = "Simon W. Jackson";
    hashedPassword = "$6$HrsjijTxzxcw3Kw4$9qLus4MLJAhOFsYheWEYI1Ky4iOJpmLgJkQoN.Gr0Wvxaq5mFf/gosOEHL3mLmE0E3LEVag2qeVmCAbgv6boK0";
    packages = with pkgs; [
      firefox
      obsidian
      tmux
      git
    ];
    extraGroups = [
      "dialout"
      "feedbackd"
      "networkmanager"
      "video"
      "wheel"
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}

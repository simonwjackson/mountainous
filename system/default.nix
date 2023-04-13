{ config, pkgs, lib, ... }:

{
  system.copySystemConfiguration = true;
  programs.zsh.enable = true;
  nixpkgs.config.allowUnfree = true;
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };

  imports = [
    ../packages/ex
    # ../packages/clockify-cli
  ];

  services.automatic-timezoned.enable = true;

  networking.useDHCP = lib.mkDefault false;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = lib.mkDefault "Lat2-Terminus16";
    keyMap = "us";
  };

  security.sudo.wheelNeedsPassword = false;

  users.defaultUserShell = pkgs.zsh;
  users.users.simonwjackson = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [
      "adbusers"
      "wheel"
    ]; # Enable ‘sudo’ for the user.
  };

  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    # Other
    wget
    git
    w3m
    ripgrep
    tmux
    lf
    _1password
    # obsidian
  ];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
    permitRootLogin = "no";
    extraConfig = ''
      #PubkeyAcceptedKeyTypes ssh-rsa
    '';
  };

  services.udev.packages = [
    pkgs.android-udev-rules
  ];

  # TTY mouse
  services.gpm.enable = true;

  # programs.ssh.hostKeyAlgorithms = [ "ssh-ed25519" "ssh-rsa" ];
  # programs.ssh.pubkeyAcceptedKeyTypes = [ "ssh-rsa" ];

  system.stateVersion = "23.05";
}

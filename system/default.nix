{ config, pkgs, ... }:

{
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  imports = [
    ../packages/ex
  ];

  networking.networkmanager.enable = true;

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  nixpkgs.config.allowUnfree = true;
  security.sudo.wheelNeedsPassword = false;

  users.defaultUserShell = pkgs.zsh;
  users.users.simonwjackson = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  };

  # List packages installed in system profile. To search, run:
  environment.variables.EDITOR = "nvim";
  programs.neovim.enable = true;
  programs.neovim.viAlias = true;

  environment.systemPackages = with pkgs; [
    # Other
    neovim
    wget
    git
    w3m
    ripgrep
    tmux
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  system.stateVersion = "22.05";
}

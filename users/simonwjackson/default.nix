{ config, pkgs, ... }:

{
  imports = [
    ./desktop
    ./terminal
    ../../modules/neovim
    ../../modules/hidpi.nix

    # Scripts
    ./bin/wikis
    ./bin/scale-desktop
    ./bin/kill-or-close
    ./bin/kitty-popup
    ./bin/vim-wiki
  ];

  home = {
    username = "simonwjackson";
    homeDirectory = "/home/simonwjackson";

    shellAliases = {
      try = "nix-shell -p";
      cat = "bat";
      sl = "exa";
      ls = "exa";
      l = "exa -l";
      la = "exa -la";
      ip = "ip --color=auto";
    };

    packages = [
      pkgs.git-crypt
      pkgs.p7zip
      pkgs.killall
      pkgs.jq
    ];
  };

  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "$HOME/desktop";
      documents = "$HOME/documents";
      download = "$HOME/downloads";
      music = "$HOME/music";
      pictures = "$HOME/images";
      templates = "$HOME/templates";
      videos = "$HOME/videos";
    };
  };

  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = {
    enable = true;
    pinentryFlavor = "gnome3";
  };

  services.udiskie = {
    enable = true;
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

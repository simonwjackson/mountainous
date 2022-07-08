{ config, pkgs, ... }:

{
  imports = [
    ./desktop
    ./terminal
    ../../modules/neovim

    # Scripts
    ./bin/wikis
    ./bin/scale-desktop
    ./bin/kill-or-close
    ./bin/kitty-popup
    ./bin/vim-wiki
    ./bin/virtual-term
  ];

  # TODO: Find a way to enable this dynamicaly by system type
  xresources = {
    properties = {
      "Xft.dpi" = 192;
    };
  };
  home = {
    sessionVariables = {
      GDK_SCALE = 2;
      GDK_DPI_SCALE = 0.5;
      QT_AUTO_SCREEN_SET_FACTOR = 0;
      QT_SCALE_FACTOR = 2;
      QT_FONT_DPI = 96;

      NVIM_LISTEN_ADDRESS = "/tmp/nvimsocket nvim";
    };
  };

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
      pkgs._1password-gui
    ];
  };

  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "$HOME/desktop";
      documents = "$HOME/documents";
      download = "$HOME/downloads";
      music = "/tank/music";
      pictures = "$HOME/images";
      templates = "$HOME/templates";
      videos = "/tank/videos";
    };
  };

  services.udiskie = {
    enable = true;
  };


  # TODO: Place this next to syncthing config
  home.file = {
    "./code/.stignore" = {
      text = ''
        **/node_modules
        **/dist
      '';
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

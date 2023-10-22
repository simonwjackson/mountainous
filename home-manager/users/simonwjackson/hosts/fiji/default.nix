{ inputs
, outputs
, lib
, config
, pkgs
, ...
}: {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    ../../global
    ./aria2.nix
    ./beets.nix
    ./firefox
    ./kitty
  ];

  home.packages = [
    pkgs.matcha-gtk-theme
  ];

  gtk = {
    enable = true;
    # iconTheme = {
    #   name = "xfce4-icon-theme";
    #   package = pkgs.xfce.xfce4-icon-theme;
    # };
    theme = {
      name = "matcha-dark-sea";
      package = pkgs.matcha-gtk-theme;
    };
    gtk3.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
    gtk4.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
  };

  # INFO: https://github.com/nix-community/home-manager/issues/1011#issuecomment-1452920285
  xdg.configFile."plasma-workspace/env/hm-session-vars.sh".text = ''
    . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
  '';

  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "/glacier/snowscape/desktop";
      documents = "/glacier/snowscape/documents";
      download = "/glacier/snowscape/downloads";
      music = "/glacier/snowscape/music";
      pictures = "/glacier/snowscape/photos";
    };
  };

  programs.vinyl-vault = {
    enable = true;
    rootDownloadPath = config.xdg.userDirs.music;
  };

  services.mpvd.enable = true;
  services.udiskie.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}

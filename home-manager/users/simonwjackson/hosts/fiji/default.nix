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

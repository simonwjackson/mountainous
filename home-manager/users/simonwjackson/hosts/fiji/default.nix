{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    ../../global
    ./aria2.nix
    ./beets.nix
    ./firefox
    ./kitty
  ];

  programs.vinyl-vault.enable = true;
  programs.work-mode.enable = true;
  services.mpvd.enable = true;
  services.udiskie.enable = true;
  simonwjackson.snowscape.enable = true;

  xresources = {
    properties = {
      "Xft.dpi" = "128";
      "Xcursor.size" = "32";
    };
  };

  # INFO: https://github.com/nix-community/home-manager/issues/1011#issuecomment-1452920285
  # xdg.configFile."plasma-workspace/env/hm-session-vars.sh".text = ''
  #   . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
  # '';

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}

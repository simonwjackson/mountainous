{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.mountainous.features.hyprland;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.hyprland = {
    enable = mkEnableOption "Hyprland Wayland compositor";
  };

  config = mkIf cfg.enable {
    mountainous.features.codexbar.enable = lib.mkDefault true;

    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}

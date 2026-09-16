{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.mountainous.features.niri;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.niri = {
    enable = mkEnableOption "Niri scrollable-tiling Wayland compositor";
  };

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}

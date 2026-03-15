{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.mountainous.presets.desktop;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.presets.desktop = {
    enable = mkEnableOption "desktop preset";
  };

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}

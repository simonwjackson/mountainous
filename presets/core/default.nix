{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.mountainous.presets.core;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.presets.core = {
    enable = mkEnableOption "core preset";
  };

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ../../home/simonwjackson
      ./home.nix
    ];
  };
}

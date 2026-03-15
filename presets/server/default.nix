{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.mountainous.presets.server;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.presets.server = {
    enable = mkEnableOption "server preset";
  };

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}

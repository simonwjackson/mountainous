{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.mountainous.features.gaming;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.gaming = import ./options.nix {inherit lib;};

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}

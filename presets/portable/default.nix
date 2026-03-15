{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.mountainous.presets.portable;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.presets.portable = {
    enable = mkEnableOption "portable preset";
  };

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}

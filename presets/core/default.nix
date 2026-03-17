{
  config,
  lib,
  mountainousPlatform ? "nixos",
  ...
}: let
  inherit (lib) mkEnableOption mkIf optional;
  cfg = config.mountainous.presets.core;
in {
  imports =
    optional (mountainousPlatform == "nixos") ./nixos.nix
    ++ optional (mountainousPlatform == "droid") ./droid.nix;

  options.mountainous.presets.core = {
    enable = mkEnableOption "core preset";
  };

  config = mkIf (cfg.enable && mountainousPlatform == "nixos") {
    home-manager.users.simonwjackson.imports = [
      ../../home/simonwjackson
      ./home.nix
    ];
  };
}

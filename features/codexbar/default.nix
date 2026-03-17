{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.features.codexbar;
in {
  options.mountainous.features.codexbar = {
    enable = mkEnableOption "CodexBar usage monitor for ironbar";

    interval = mkOption {
      type = types.int;
      default = 120000;
      description = "Polling interval in milliseconds (default: 2 minutes)";
    };
  };

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}

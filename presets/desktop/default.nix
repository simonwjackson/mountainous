{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.mountainous.presets.desktop;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.presets.desktop = {
    enable = mkEnableOption "desktop preset";
    defaultMode = mkOption {
      type = types.enum ["dark" "light"];
      default = "dark";
      description = "The default appearance mode written to user config files before darkman applies any runtime changes.";
    };
  };

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}

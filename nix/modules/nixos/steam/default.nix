{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.mountainous.steam;
in {
  options.mountainous.steam = {
    enable = mkEnableOption "Steam gaming platform with full runtime support";
  };

  config = mkIf cfg.enable {
    programs.steam.enable = true;
    programs.steam.extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];

    environment.systemPackages = with pkgs; [
      gamescope
      steam
      steam-tui
      gamemode
      mangohud
    ];

    programs.steam.protontricks.enable = true;
  };
}

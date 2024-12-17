{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  cfg = config.mountainous.gaming.steam;

  inherit (inputs.elevate.packages.${system}) proton-ge-custom steam-launch;
in {
  options.mountainous = {
    gaming.steam = {
      enable = lib.mkEnableOption "Enable steam";
    };
  };

  config = lib.mkIf cfg.enable {
    mountainous.services.gamescope-reaper.enable = true;

    environment.systemPackages = with pkgs; [
      steam-launch
    ];

    hardware = {
      steam-hardware.enable = true;
      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };

    programs = {
      steam = {
        enable = true;
        remotePlay.openFirewall = true;
        extest.enable = true;
        package = pkgs.steam.override {
          extraPkgs = pkgs:
            with pkgs; [
              mangohud
              gamescope-wsi_git
              gamescope_git
            ];
        };
        extraCompatPackages = [
          proton-ge-custom
        ];
      };
    };
  };
}

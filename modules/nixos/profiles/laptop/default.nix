{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.profiles.laptop;
in {
  options.mountainous.profiles.laptop = {
    enable = lib.mkEnableOption "Whether to enable laptop configurations";
  };

  config = lib.mkIf cfg.enable {
    mountainous = {
      hardware = {
        touchpad = enabled;
        battery = enabled;
        hybrid-sleep = enabled;
      };
    };

    services.syncthing-auto-pause = {
      enable = true;
      managedShares = [
        "games"
        "videos"
      ];
    };

    environment.systemPackages = with pkgs; [
      acpi
    ];
  };
}

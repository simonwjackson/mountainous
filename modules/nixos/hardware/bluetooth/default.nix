{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types;

  cfg = config.mountainous.hardware.bluetooth;
in {
  options.mountainous.hardware.bluetooth = {
    enable = mkEnableOption "Whether to enable bluetooth";
    device = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Bluetooth device MAC address";
      example = "D4:D8:53:90:2B:70";
    };
  };

  config = mkIf cfg.enable {
    hardware = {
      bluetooth = {
        enable = true;
        powerOnBoot = true; # powers up the default Bluetooth controller on boot
      };
    };

    age.secrets = mkIf (cfg.device != null) {
      bluetooth-fuji-sony-ote = {
        path = lib.mkForce "/var/lib/bluetooth/${cfg.device}/CC:98:8B:93:2A:1F/info";
        owner = lib.mkForce "root";
        group = lib.mkForce "root";
        mode = lib.mkForce "0600";
      };
    };

    services.blueman.enable = true;

    environment.systemPackages = with pkgs; [
      bluetuith
      bluetui
    ];
  };
}

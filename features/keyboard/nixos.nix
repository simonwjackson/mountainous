{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.features.keyboard;
  kanataConfig = pkgs.writeText "mountainous-kanata.kbd" cfg.config;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    boot.kernelModules = ["uinput"];

    services.udev.extraRules = ''
      KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"

      # Ignore the ThinkPad Bluetooth keyboard's integrated touchpad on any
      # machine where this keyboard is attached.
      ACTION=="add|change", SUBSYSTEM=="input", ATTRS{name}=="ThinkPad Bluetooth TrackPoint Keyboard Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    '';

    systemd.services.kanata = {
      description = "Kanata keyboard remapper";
      wantedBy = ["multi-user.target"];
      after = ["systemd-udevd.service"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe cfg.package} --cfg ${kanataConfig}";
        Restart = "always";
        RestartSec = "3";
        User = "root";
        Group = "root";
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        DeviceAllow = [
          "/dev/uinput rw"
          "char-input r"
        ];
      };
    };
  };
}

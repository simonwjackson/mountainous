{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.kanata;
in {
  options.mountainous.kanata = {
    enable = mkEnableOption "kanata keyboard remapping";

    device = mkOption {
      type = types.str;
      description = "Input device path for the keyboard";
      example = "/dev/input/by-id/usb-Huawei-keyboard";
    };

    config = mkOption {
      type = types.lines;
      default = "";
      description = "Kanata configuration (defsrc, defalias, deflayer, defchordsv2)";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.kanata];

    systemd.services.kanata = {
      description = "Kanata keyboard remapper";
      wantedBy = ["multi-user.target"];
      after = ["systemd-udevd.service"];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kanata}/bin/kanata --cfg ${pkgs.writeText "kanata.kbd" ''
          (defcfg
            linux-dev "${cfg.device}"
            process-unmapped-keys yes
            concurrent-tap-hold yes
          )

          ${cfg.config}
        ''}";
        Restart = "always";
        RestartSec = "3";

        # Run as root for uinput access
        User = "root";
        Group = "root";

        # Hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        DeviceAllow = [
          "/dev/uinput rw"
          "char-input r"
        ];
      };
    };

    # Ensure uinput module is loaded
    boot.kernelModules = ["uinput"];

    # udev rules for uinput access
    services.udev.extraRules = ''
      KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
    '';
  };
}

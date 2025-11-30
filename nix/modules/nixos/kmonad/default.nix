{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.kmonad;
in {
  options.mountainous.kmonad = {
    enable = mkEnableOption "kmonad keyboard remapping";

    device = mkOption {
      type = types.str;
      description = "Input device path for the keyboard";
      example = "/dev/input/by-id/usb-Huawei-keyboard";
    };

    config = mkOption {
      type = types.lines;
      default = "";
      description = "Additional kmonad configuration (defsrc, defalias, deflayer)";
    };
  };

  config = mkIf cfg.enable {
    services.kmonad = {
      enable = true;
      keyboards.main = {
        device = cfg.device;
        defcfg = {
          enable = true;
          fallthrough = true;
          allowCommands = false;
        };
        config = cfg.config;
      };
    };

    # Fix permission issues with uinput access
    systemd.services.kmonad-main.serviceConfig = {
      PrivateUsers = lib.mkForce false;
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "root";
      Group = lib.mkForce "root";
    };
  };
}

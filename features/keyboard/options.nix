{lib}: let
  inherit (lib) mkEnableOption mkOption types;
in {
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
}

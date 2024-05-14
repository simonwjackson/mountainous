{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.mountainous.adb;
in {
  options.mountainous.adb = {
    enable = mkEnableOption "Whether to enable adb tooling";
  };

  config = mkIf cfg.enable {
    programs.adb.enable = true;
    users.users."${config.mountainous.user.name}".extraGroups = ["adbusers"];
    services.udev.packages = [
      pkgs.android-udev-rules
    ];
  };
}

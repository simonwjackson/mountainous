{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.performance;
  powertop = lib.getExe pkgs.powertop;
in {
  options.mountainous.performance = {
    enable = lib.mkEnableOption "Enable performance tuning";
  };

  config = lib.mkIf cfg.enable {
    services.auto-cpufreq.enable = true;
    powerManagement.enable = true;
    powerManagement.powertop.enable = true;

    # INFO: Hacky, non-reliable way to check if host is intel
    services.thermald.enable = config.hardware.cpu.intel.updateMicrocode;

    systemd.services.powertop = lib.mkIf config.mountainous.battery.enable {
      # description = "Auto-tune Power Management with powertop";
      unitConfig = {RefuseManualStart = true;};
      wantedBy = ["battery.target" "ac.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${powertop} --auto-tune";
      };
    };
  };
}

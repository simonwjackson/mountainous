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
    # a shell daemon created to manage processes' IO and CPU priorities, with community-driven set of rule
    services.ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
    };

    services.auto-cpufreq.enable = true;

    powerManagement = {
      enable = true;
      powertop.enable = true;
      cpuFreqGovernor = pkgs.lib.mkDefault "powersave";
    };

    # INFO: Hacky, non-reliable way to check if host is intel
    services.thermald.enable = config.mountainous.hardware.cpu.type == "intel";

    systemd.services.powertop = lib.mkIf config.mountainous.hardware.battery.enable {
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

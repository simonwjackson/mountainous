{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.performance;
  powertop = lib.getExe pkgs.powertop;
in {
  options.mountainous.performance = {
    enable = lib.mkEnableOption "Enable performance tuning";
  };

  config = lib.mkIf cfg.enable {
    services = {
      auto-cpufreq = enabled;
      ananicy = {
        # a shell daemon created to manage processes' IO and CPU priorities, with community-driven set of rule
        enable = true;
        package = pkgs.ananicy-cpp;
      };
    };

    programs.ccache = enabled;

    # systemd.services.powertop = lib.mkIf config.mountainous.hardware.battery.enable {
    #   # description = "Auto-tune Power Management with powertop";
    #   unitConfig = {RefuseManualStart = true;};
    #   wantedBy = ["battery.target" "ac.target"];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     ExecStart = "${powertop} --auto-tune";
    #   };
    # };

    zramSwap = enabled;
  };
}

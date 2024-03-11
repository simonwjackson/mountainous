{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.laptop;
in {
  options.services.laptop = {
    enable = mkEnableOption "Power management configuration";
  };

  config = mkIf cfg.enable {
    services.auto-cpufreq.enable = true;

    # INFO: Hacky, non-reliable way to check if host is intel
    services.thermald.enable = mkIf (config.hardware.cpu.intel.updateMicrocode) true;

    systemd.targets.ac = {
      conflicts = ["battery.target"];
      description = "On AC power";
      unitConfig = {DefaultDependencies = "false";};
    };

    systemd.targets.battery = {
      conflicts = ["ac.target"];
      description = "On battery power";
      unitConfig = {DefaultDependencies = "false";};
    };

    # systemd.services.power-maximum-tdp = {
    #   description = "Change TDP to maximum TDP when on AC power";
    #   wantedBy = ["ac.target"];
    #   unitConfig = {RefuseManualStart = true;};
    #   serviceConfig = {
    #     Type = "oneshot";
    #     ExecStart = "${pkgs.ryzenadj}/bin/ryzenadj --stapm-limit=28000 --fast-limit=28000 --slow-limit=28000 --tctl-temp=90";
    #   };
    # };

    # systemd.services.power-saving-tdp = {
    #   description = "Change TDP to power saving TDP when on battery power";
    #   wantedBy = ["battery.target"];
    #   unitConfig = {RefuseManualStart = true;};
    #   serviceConfig = {
    #     Type = "oneshot";
    #     ExecStart = "${pkgs.ryzenadj}/bin/ryzenadj --stapm-limit=3000 --fast-limit=3000 --slow-limit=3000 --tctl-temp=90";
    #   };
    # };

    systemd.services.powertop = {
      # description = "Auto-tune Power Management with powertop";
      unitConfig = {RefuseManualStart = true;};
      wantedBy = ["battery.target" "ac.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.powertop}/bin/powertop --auto-tune";
      };
    };

    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl start ac.target"
      SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl start battery.target"
    '';
  };
}

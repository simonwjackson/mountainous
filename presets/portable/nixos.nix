{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.presets.portable;
in {
  config = mkIf cfg.enable {
    networking.wireless.enable = lib.mkDefault false;
    environment.systemPackages = mkDefault [pkgs.acpi];

    networking.networkmanager.wifi.powersave = mkDefault true;

    services.upower.enable = mkDefault true;

    services.tlp = {
      enable = mkDefault true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = mkDefault "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = mkDefault "powersave";

        CPU_ENERGY_PERF_POLICY_ON_AC = mkDefault "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = mkDefault "power";

        CPU_BOOST_ON_AC = mkDefault 1;
        CPU_BOOST_ON_BAT = mkDefault 0;

        WIFI_PWR_ON_AC = mkDefault "off";
        WIFI_PWR_ON_BAT = mkDefault "on";
      };
    };

    services.thermald.enable = mkDefault (config.hardware.cpu.intel.updateMicrocode or false);
    services.power-profiles-daemon.enable = mkDefault false;
    services.auto-cpufreq.enable = mkDefault false;

    services.libinput = {
      enable = mkDefault true;
      touchpad = {
        disableWhileTyping = mkDefault true;
        tapping = mkDefault true;
      };
    };

    systemd.sleep.settings.Sleep.HibernateDelaySec = mkDefault "15min";

    services.logind.settings.Login = {
      HandleLidSwitch = mkDefault "suspend-then-hibernate";
      HandleLidSwitchExternalPower = mkDefault "suspend-then-hibernate";
      HandleLidSwitchDocked = mkDefault "ignore";
      HandlePowerKey = mkDefault "hibernate";
      HandleSuspendKey = mkDefault "suspend-then-hibernate";
      HandleHibernateKey = mkDefault "hibernate";
    };
  };
}

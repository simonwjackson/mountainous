{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.profiles.laptop;
in {
  options.mountainous.profiles.laptop = {
    enable = lib.mkEnableOption "Wether to enable laptop configurations";
  };

  config = lib.mkIf cfg.enable {
    # Sleep
    systemd.sleep.extraConfig = ''
      # 15min delay
      HibernateDelaySec=900
    '';

    services.logind.lidSwitch = "suspend-then-hibernate";
    services.logind.lidSwitchExternalPower = "suspend";

    services.logind.extraConfig = ''
      HandlePowerKey=suspend-then-hibernate
      HandleSuspendKey=suspend-then-hibernate
      HandleHibernateKey=suspend-then-hibernate
      IdleAction=hibernate
      IdleActionSec=15min
    '';

    environment.systemPackages = with pkgs; [
      acpi
    ];

    services.libinput.enable = true;
    services.libinput.touchpad.disableWhileTyping = true;
    services.libinput.touchpad.tapping = true;
  };
}

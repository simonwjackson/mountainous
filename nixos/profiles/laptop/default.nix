{ pkgs, ... }: {
  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;
  services.xserver.libinput.touchpad.disableWhileTyping = true;
  services.xserver.libinput.touchpad.tapping = true;
  services.geoclue2.enable = true;

  powerManagement.enable = true;
  powerManagement.powertop.enable = true;

  environment.systemPackages = with pkgs; [
    acpi
  ];

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
  '';
}

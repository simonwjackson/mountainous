{ config, pkgs, modulesPath, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    acpi
  ];

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver = {
    libinput.enable = true;
    inputClassSections = [
      ''
        Section "InputClass"
          Identifier "libinput touchpad catchall"
          MatchIsTouchpad "on"
          MatchDevicePath "/dev/input/event*"
          Driver "libinput"
          Option "Tapping" "on"
          Option "PalmDetection" "1"
          Option "PalmSize" "30" # Adjust this value if needed
          Option "PalmPressure" "100" # Adjust this value if needed
        EndSection
      ''
    ];
  };
}

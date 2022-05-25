{ config, pkgs, modulesPath, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    acpi
  ];

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;
}

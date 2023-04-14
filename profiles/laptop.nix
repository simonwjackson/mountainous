{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    acpi
  ];
}

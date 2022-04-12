{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    # <nixos-hardware/microsoft/surface>
    ./hardware-configuration.nix
    ../../modules/workstation.nix
    ../default.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "fiji"; # Define your hostname.
}

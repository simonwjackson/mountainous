{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.snowfall.fs) get-file;
  inherit (lib) mkIf mkDefault;
  inherit (lib.mountainous) enabled disabled;
  inherit (lib.mountainous.util) allHosts;
  inherit (lib.mountainous.syncthing) otherDevices;
in {
  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = ["xhci_pci" "usbhid" "usb_storage"];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = ["noatime"];
    };
  };

  networking = {
    networkmanager.enable = true;
  };

  environment.systemPackages = with pkgs; [vim];

  security.sudo.wheelNeedsPassword = false;

  users = {
    mutableUsers = false;
    users.simonwjackson = {
      isNormalUser = true;
      extraGroups = ["wheel"];
    };
  };

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "24.11";

  #############

  programs.icho = {
    enable = false;
  };

  mountainous = {
    adb.enable = false;
    agenix = {
      enable = lib.mkForce false;
    };
    desktops = {
      hyprlandControl = enabled;
      hyprland = {
        enable = true;
        autoLogin = true;
      };
    };
    boot.enable = false;
    networking = {
      core.enable = false;
      tailscaled = {
        enable = lib.mkForce false;
      };
      zerotierone.enable = false;
      secure-shell = {
        systemsDir = get-file "systems";
      };
    };
    performance.enable = false;
    printing.enable = false;
    security.enable = false;
    syncthing = {
      enable = false;
    };
    user = {
      enable = false;
    };
  };
}

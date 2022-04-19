{ config, pkgs, modulesPath, lib, ... }:

let
  wifi = {
    mac = "7c:50:79:4f:03:2b";
    name = "wifi";
  };

in
{
  imports = [
    # Include the results of the hardware scan.
    ../modules/workstation.nix
    #../modules/wireguard-client.nix
    ./default.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostName = "fiji"; # Define your hostname.

  boot = {
    loader = {
      # Use the systemd-boot EFI boot loader.
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    extraModulePackages = [ ];
    initrd = {
      availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    kernelPatches =
      {
        extraConfig = ''
          CONFIG_SERIAL_DEV_BUS y
          CONFIG_SERIAL_DEV_CTRL_TTYPORT y
        '';
      };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

    "/storage" = {
      device = "/dev/disk/by-label/storage";
    };

    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };

    "/tmp" = {
      device = "/storage/tmp";
      options = [ "bind" ];
    };

    "/home" = {
      device = "/storage/home";
      options = [ "bind" ];
    };
  };


  swapDevices =
    [{ device = "/dev/disk/by-label/swap"; }];

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = lib.mkDefault false;
  networking.interfaces.wlp0s20f3.useDHCP = lib.mkDefault true;

  powerManagement.enable = true;
  powerManagement.powertop.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "balanced";

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.bluetooth.enable = true;
  hardware.video.hidpi.enable = lib.mkDefault true;

  # Screen tearing
  # https://nixos.org/manual/nixos/unstable/index.html#sec-x11--graphics-cards-intel
  services.xserver.videoDrivers = [ "modesetting" ];
  services.xserver.useGlamor = true;

  # services.xserver.videoDrivers = [ "intel" ];
  # services.xserver.deviceSection = ''
  #   Option "DRI" "2"
  #   Option "TearFree" "true"
  # '';

  services.udev.extraRules = ''
    # any user can change perf_mode
    # KERNEL=="01:03:01:00:01", SUBSYSTEM=="surface_aggregator", RUN+="/usr/bin/chmod 666 /sys/bus/surface_aggregator/devices/01:03:01:00:01/perf_mode"
    KERNEL=="wlan*", ATTR{address}=="${wifi.mac}", NAME = "${wifi.name}"
  '';

  environment.systemPackages = with pkgs;
    [
      acpi
      surface-control
    ];

  networking.firewall = {
    allowedUDPPorts = [ 51820 ]; # Clients and peers can use the same port, see listenport
  };

  # networking.wireguard.interfaces = {
  #   mtn = {
  #     ips = [ "192.18.1.10/32" ];
  #     #privateKeyFile = "path to private key file";
  #   };
  # };
}

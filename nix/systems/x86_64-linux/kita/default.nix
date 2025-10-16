{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  environment.systemPackages = with pkgs; [
    moonlight-qt
  ];

  services = {
    openssh.enable = true;
  };

  # Boot configuration for Intel NUC8i3BEK
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "ahci" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
    kernelParams = [
      "i915.enable_gvt=1"
      "intel_idle.max_cstate=1"
    ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # Hardware configuration for Intel NUC8i3BEK with i3-8109U
  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
  };

  # Graphics configuration for Intel Iris Plus Graphics 655
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but sometimes works better)
      vaapiVdpau
      libvdpau-va-gl
    ];
    extraPackages32 = with pkgs; [
      intel-media-driver
      vaapiIntel
    ];
  };

  # Networking
  networking.hostName = "kita";
  networking.useDHCP = lib.mkDefault true;

  # System profile
  mountainous = {
    profiles = {
      base.enable = true;
      workspace.enable = true;
      gaming.enable = true;
    };
    disks = {
      frostbite = {
        enable = true;
        device = "/dev/sda";
        swapSize = "8G";
        encrypt = false;
      };
    };
  };

  system.stateVersion = "24.05";
}

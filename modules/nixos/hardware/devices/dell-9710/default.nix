{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkDefault;
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.hardware.devices.dell-9710;
in {
  options.mountainous.hardware.devices.dell-9710 = {
    enable = mkEnableOption "Whether to enable bluetooth";
  };

  config = mkIf cfg.enable {
    mountainous = {
      hardware = {
        bluetooth.enable = true;
        cpu.type = "intel";
        battery = enabled;
      };
    };

    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "thunderbolt"
      "nvme"
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];

    boot.kernelModules = [
      "kvm-intel"
      "uinput"
    ];

    boot.kernelPackages = mkDefault pkgs.linuxPackages_zen;

    # hardware.opengl.enable = true;
    hardware.nvidia.prime = {
      offload.enable = lib.mkForce true;
      nvidiaBusId = "PCI:1:0:0";
      intelBusId = "PCI:0:2:0";
    };

    services.xserver.videoDrivers = ["nvidia"];

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;
  };
}

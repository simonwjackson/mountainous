{ config, lib, pkgs, modulesPath, ... }: {
  imports = [
    <nixos-hardware/dell/xps/17-9700/nvidia>
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "usbhid" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  boot.kernelModules = [ "kvm-intel" "uinput" ];
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Includes the Wi-Fi and Bluetooth firmware
  hardware.enableRedistributableFirmware = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

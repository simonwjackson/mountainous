{ modulesPath, lib, ... }:

{
  imports = [
    ./apple-silicon-support
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.efi.canTouchEfiVariables = false;
  hardware.bluetooth.enable = true;
  boot.initrd.availableKernelModules = [ "usb_storage" "sdhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelParams = [
    "apple_dcp.show_notch=1"
  ];
  boot.extraModulePackages = [ ];
  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0
  '';
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
  hardware.asahi.addEdgeKernelConfig = true;
}

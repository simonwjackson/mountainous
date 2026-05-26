{...}: {
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
  ];

  boot.kernelModules = [
    "igb" # Intel I211 Gigabit NIC
    "cp210x" # USB-to-serial for HubZ Smart Home Controller
    "mt7921u" # MediaTek MT7921U WiFi (Netgear A8000)
  ];

  # Udev rules for HubZ Smart Home Controller
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="8a2a", ATTRS{bInterfaceNumber}=="00", SYMLINK+="zwave"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="8a2a", ATTRS{bInterfaceNumber}=="01", SYMLINK+="zigbee"
  '';
}

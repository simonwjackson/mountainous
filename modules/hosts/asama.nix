{ inputs, ... }:
{
  nixos.hosts.asama = {
    enrolled = false;
    system = "aarch64-linux";
    nixpkgs = inputs.korri.inputs.nixpkgs;
    # No Denial until its native arm64 Nix toolchain is pinned.
    layers = [
      "desktop-shared"
      "phone"
      "nx809j"
      "korri"
    ];
    module = {
      services.korriProduct.usbGadget = {
        name = "asama";
        product = "Asama NixOS";
        address = "10.42.249.1";
        hostMac = "02:00:00:00:f9:01";
        deviceMac = "02:00:00:00:f9:02";
      };
      # Provisional until the phone arrives. The Linux ESP is NOT efisp.
      fileSystems."/" = {
        device = "/dev/disk/by-partlabel/linux";
        fsType = "ext4";
      };
      fileSystems."/boot" = {
        device = "/dev/disk/by-partlabel/linux-esp";
        fsType = "vfat";
      };
    };
  };
}

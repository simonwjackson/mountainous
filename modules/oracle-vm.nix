# An Oracle Cloud Ampere A1 VM: QEMU/KVM guest, one boot volume, a VCN lease.
#
# Pair it with `server` and `permafrost`. The host file then names only its
# boot volume and its role.
{
  nixos.modules.oracle-vm =
    { lib, modulesPath, ... }:
    {
      # virtio_scsi, virtio_pci and the other QEMU guest drivers. The base
      # layer only lists bare-metal controllers, and without these the initrd
      # cannot find the boot disk.
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
      boot.initrd.availableKernelModules = [
        "virtio_scsi"
        "virtio_pci"
      ];

      # Keep the DHCP client that holds the VCN lease. NetworkManager adds
      # nothing on a VM with one virtual NIC.
      networking.networkmanager.enable = lib.mkForce false;
      networking.useDHCP = true;

      # post-boot and sleep-actions do nothing on a VM that never sleeps and
      # has no CPU frequency control.
      powerManagement.enable = false;
    };
}

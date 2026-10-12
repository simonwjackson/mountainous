# Oracle Cloud Ampere A1 VM (aarch64), ported in place from the unified branch.
# Media and messaging moved off this host. Do not run Disko or an installer
# here: the partitions below already hold the root filesystem.
{
  nixos.hosts.yari = {
    system = "aarch64-linux";
    layers = [ "server" ];
    module =
      { lib, modulesPath, ... }:
      {
        # virtio_scsi, virtio_pci and the other QEMU guest drivers. The base
        # layer only lists bare-metal controllers, and without these the
        # initrd cannot find the boot disk.
        imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
        boot.initrd.availableKernelModules = [
          "virtio_scsi"
          "virtio_pci"
          "xfs"
        ];

        # The existing partitions, by the labels the original Disko layout
        # wrote. Declared directly so no Disko module can format anything.
        fileSystems."/" = {
          device = "/dev/disk/by-partlabel/disk-boot-root";
          fsType = "xfs";
        };
        fileSystems."/boot" = {
          device = "/dev/disk/by-partlabel/disk-boot-ESP";
          fsType = "vfat";
        };

        # Keep the DHCP client that already holds the VCN lease.
        networking.networkmanager.enable = lib.mkForce false;
        networking.useDHCP = true;
        services.automatic-timezoned.enable = lib.mkForce false;
        time.timeZone = "UTC";

        # simon takes the old account's UID so files such as Fuji's backup
        # mirror stay owned by the operator. The old home stays on disk.
        users.users.simon.uid = 1000;

        system.stateVersion = "24.11";
      };
  };
}

# Oracle Cloud Ampere A1 VM (aarch64): a dedicated Forgerie host.
#
# The disk layout is the permafrost layer (modules/permafrost.nix), applied by
# a fresh install with `nix run .#install`. Until that install, Yari still
# runs on its old XFS root: do not switch that system to this config, because
# its filesystems do not exist there. See docs/plans/yari-forgerie-host.md.
{
  nixos.hosts.yari = {
    system = "aarch64-linux";
    layers = [
      "server"
      "permafrost"
    ];
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
        ];

        # The Oracle boot volume. The id is the volume's WWN, which stays the
        # same in the RAM installer and the installed system.
        mountainous.permafrost.device = "/dev/disk/by-id/scsi-3600746698fac4cdbbc994001bebb9e91";

        # 23 GiB of RAM and no disk swap. Without swap, one memory spike lets
        # the OOM killer stop forgerie-sessiond and every session in it.
        zramSwap.enable = true;

        # Keep the DHCP client that already holds the VCN lease.
        networking.networkmanager.enable = lib.mkForce false;
        networking.useDHCP = true;
        services.automatic-timezoned.enable = lib.mkForce false;
        time.timeZone = "UTC";

        users.users.simon.uid = 1000;

        system.stateVersion = "24.11";
      };
  };
}

# Oracle Cloud Ampere A1 VM (aarch64): a dedicated Forgerie host.
#
# The disk layout is the permafrost layer (modules/permafrost.nix), installed
# on 2026-10-12 with `nix run .#install`. Change it with `nixos-rebuild`. See
# docs/plans/yari-forgerie-host.md.
{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.yari-network =
        let
          c = self.nixosConfigurations.yari.config;
        in
        assert c.boot.kernel.sysctl."net.ipv4.tcp_congestion_control" == "bbr";
        assert c.boot.kernel.sysctl."net.core.default_qdisc" == "fq";
        assert builtins.elem "tcp_bbr" c.boot.kernelModules;
        pkgs.runCommand "yari-network" { } "touch $out";
    };

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
        # BBR instead of cubic. The Oracle -> home route crosses a lossy
        # NTT -> Cogent handoff (about 1.5% loss at 100 ms). Cubic fell to
        # 0.3-0.7 MiB/s there; BBR kept 14-15 MiB/s (measured 2026-10-13).
        boot.kernelModules = [ "tcp_bbr" ];
        boot.kernel.sysctl = {
          "net.ipv4.tcp_congestion_control" = "bbr";
          "net.core.default_qdisc" = "fq";
        };

        services.automatic-timezoned.enable = lib.mkForce false;
        time.timeZone = "UTC";

        users.users.simon.uid = 1000;

        system.stateVersion = "24.11";
      };
  };
}

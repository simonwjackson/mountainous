# Oracle Cloud Ampere A1 VM (aarch64): the Forgerie host, and the fleet's
# second aarch64 builder.
#
# The disk layout is the permafrost layer (modules/permafrost.nix), installed
# on 2026-10-12 with `nix run .#install`. Change it with `nixos-rebuild`. See
# docs/plans/yari-forgerie-host.md.
{
  nixos.hosts.yari = {
    system = "aarch64-linux";
    layers = [
      "server"
      "permafrost"
      "oracle-vm"
      "builder"
    ];
    module = {
      # The Oracle boot volume. The id is the volume's WWN, which stays the
      # same in the RAM installer and the installed system.
      mountainous.permafrost.device = "/dev/disk/by-id/scsi-3600746698fac4cdbbc994001bebb9e91";

      # Forgerie sessions come first. Builds use the CPU and disk only when
      # Forgerie leaves them idle.
      nix.daemonCPUSchedPolicy = "idle";
      nix.daemonIOSchedClass = "idle";

      system.stateVersion = "24.11";
    };
  };
}

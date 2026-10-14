# Oracle Cloud Ampere A1 VM (aarch64): the fleet's main aarch64 builder, and
# nothing else.
#
# Ported from hosts/fuji on the `unified` branch, onto the permafrost layer.
# The operator chose which old services to keep on 2026-10-13: only the
# builder. Syncthing, the scheduled syncs, Borg and the hand-started game
# streaming were left behind. See docs/plans/fuji-permafrost.md.
{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      checks.fuji-host =
        let
          c = self.nixosConfigurations.fuji.config;
        in
        # Builds are signed with the key Korri and Zao already trust.
        assert c.nix.settings.secret-key-files == [ c.sops.secrets.nix-signing-key.path ];
        assert lib.hasPrefix "/run/" c.sops.secrets.nix-signing-key.path;
        # The nix-daemon builds under /nix/var/nix/builds, on disk. A build in
        # the tmpfs root or /tmp would compete with RAM.
        assert (c.nix.settings.build-dir or null) == null;
        assert c.fileSystems."/nix".fsType == "btrfs";
        # A builder and nothing else.
        assert !c.services.syncthing.enable;
        assert c.boot.binfmt.emulatedSystems == [ ];
        pkgs.runCommand "fuji-host" { } "touch $out";
    };

  nixos.hosts.fuji = {
    system = "aarch64-linux";
    layers = [
      "server"
      "permafrost"
      "oracle-vm"
      "builder"
    ];
    module = {
      # The Oracle boot volume, by WWN.
      mountainous.permafrost.device = "/dev/disk/by-id/scsi-360dcd7caf93c46798175207d39b51cf7";

      # The `fuji-1` key from secrets/hosts/fuji.yaml.
      mountainous.builder.signingKey = true;

      system.stateVersion = "24.11";
    };
  };
}

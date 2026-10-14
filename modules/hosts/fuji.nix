# Oracle Cloud Ampere A1 VM (aarch64): the fleet's aarch64 builder, and
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
          fw = c.networking.firewall;
        in
        # Builds are signed with the key Korri and Zao already trust.
        assert c.nix.settings.secret-key-files == [ c.sops.secrets.nix-signing-key.path ];
        assert lib.hasPrefix "/run/" c.sops.secrets.nix-signing-key.path;
        # The nix-daemon builds under /nix/var/nix/builds, on disk. A build in
        # the tmpfs root or /tmp would compete with RAM.
        assert (c.nix.settings.build-dir or null) == null;
        assert c.fileSystems."/nix".fsType == "btrfs";
        # SSH only over Tailscale: nothing listens on the public interface.
        assert fw.enable;
        assert fw.allowedTCPPorts == [ ];
        assert fw.interfaces.tailscale0.allowedTCPPorts == [ 22 ];
        # A builder and nothing else.
        assert !c.services.syncthing.enable;
        assert c.boot.binfmt.emulatedSystems == [ ];
        assert !c.powerManagement.enable;
        pkgs.runCommand "fuji-host" { } "touch $out";
    };

  nixos.hosts.fuji = {
    system = "aarch64-linux";
    layers = [
      "server"
      "permafrost"
    ];
    module =
      {
        config,
        inputs,
        lib,
        modulesPath,
        ...
      }:
      {
        # virtio_scsi, virtio_pci and the other QEMU guest drivers. The base
        # layer only lists bare-metal controllers, and without these the
        # initrd cannot find the boot disk.
        imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
        boot.initrd.availableKernelModules = [
          "virtio_scsi"
          "virtio_pci"
        ];

        # The Oracle boot volume, by WWN.
        mountainous.permafrost.device = "/dev/disk/by-id/scsi-360dcd7caf93c46798175207d39b51cf7";

        # 23 GiB of RAM and no disk swap. A large link step should slow down,
        # not wake the OOM killer.
        zramSwap.enable = true;

        # Keep the DHCP client that already holds the VCN lease.
        networking.networkmanager.enable = lib.mkForce false;
        networking.useDHCP = true;
        # BBR, for the same lossy Oracle -> home route as Yari (modules/hosts/yari.nix).
        boot.kernelModules = [ "tcp_bbr" ];
        boot.kernel.sysctl = {
          "net.ipv4.tcp_congestion_control" = "bbr";
          "net.core.default_qdisc" = "fq";
        };

        services.automatic-timezoned.enable = lib.mkForce false;
        time.timeZone = "UTC";

        users.users.simon.uid = 1000;

        # SSH only over Tailscale. The kexec installer carries Fuji's
        # Tailscale state, so the install also arrives over Tailscale. If
        # tailscaled ever fails, the Oracle serial console is the way in.
        services.openssh.openFirewall = false;
        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

        # post-boot and sleep-actions do nothing on a VM that never sleeps.
        powerManagement.enable = false;

        # ── Builder ─────────────────────────────────────────────────────
        # The `fuji-1` key. Korri's cache and Zao trust builds signed with it.
        sops.secrets.nix-signing-key = {
          sopsFile = ../../secrets/hosts/fuji.yaml;
          mode = "0400";
        };
        nix.settings.secret-key-files = [ config.sops.secrets.nix-signing-key.path ];

        # Read Korri's cache instead of building what a peer already signed.
        # Korri owns the URL and the trusted keys.
        nix.settings.substituters = [ inputs.korri.cache.url ];
        nix.settings.trusted-public-keys = inputs.korri.cache.publicKeys;

        # Zao's nix-daemon sends its aarch64 builds here (ssh-ng). The key is
        # forced to run the daemon and nothing else, so a stolen copy gives a
        # build slot, not a shell in a wheel account.
        users.users.simon.openssh.authorizedKeys.keys = [
          "restrict,command=\"${config.nix.package}/bin/nix-daemon --stdio\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAW4YRgdrxZjOPks6Jy8q4txJ4LZTVUFhNadApat21AG root@zao for remote builders"
        ];

        system.stateVersion = "24.11";
      };
  };
}

# Intel i7-9700K / ASRock Z390 Phantom Gaming-ITX/ac headless server.
# Disko prepares the initial NVMe pool; applying it to hardware is destructive.
{ inputs, self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
        unzen-storage = import ../../tests/unzen-storage.nix {
          inherit pkgs;
          diskoLib = inputs.disko.lib;
        };
        unzen-boot =
          let
            c = self.nixosConfigurations.unzen.config;
          in
          # The KIOXIA was removed; only the WD ESP may be a boot target.
          assert c.fileSystems."/boot".device == "/dev/disk/by-partlabel/disk-unzen-sn770-ESP";
          assert !(c.fileSystems ? "/boot-secondary");
          assert map (m: m.path) c.boot.loader.grub.mirroredBoots == [ "/boot" ];
          assert builtins.elem "x-systemd.requires=tailscale-online.target"
            c.fileSystems."/net/mountainous/zao/media".options;
          assert lib.hasSuffix "/bin/tailscale wait"
            c.systemd.services.tailscale-wait-online.serviceConfig.ExecStart;
          pkgs.runCommand "unzen-boot" { } "touch $out";
      };
    };

  nixos.hosts.unzen = {
    system = "x86_64-linux";
    layers = [
      "server"
      "media-applications"
      "media-scryer"
      "media-runtime"
      "media-identities"
      "media-placement-unzen"
    ];

    module =
      { config, lib, ... }:
      {
        imports = [
          inputs.disko.nixosModules.disko
          ../../disks/unzen.nix
        ];
        mountainous.features.cliproxyapi-updater.enable = true;
        # Live admission proved main-only routing before registering this host.
        mountainous.features.github-actions.enable = true;
        sops.secrets.github-actions-forgerie-app-key = {
          sopsFile = ../../secrets/hosts/unzen-github-actions.yaml;
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = [ "github-runner-forgerie.service" ];
        };
        services.github-runners.forgerie.githubApp = {
          id = 5264213;
          login = "forgerie";
          privateKeyFile = config.sops.secrets.github-actions-forgerie-app-key.path;
        };
        nix.settings = {
          extra-substituters = [ "https://github.com/simonwjackson/nix-extras/releases/download/cache/" ];
          extra-trusted-public-keys = [ "nix-extras-ci-1:+Vcq7i6dPWOsOZjQwOduCEZOZZJznS/XfOcNUhFmg3Q=" ];
        };
        boot.supportedFilesystems = [ "bcachefs" ];

        # The KIOXIA (onboard.kioxia) failed repeatedly and left the pool on
        # 2026-10-15. disks/unzen.nix still records the original two-drive
        # install, which must never be rerun. The WD ESP is now the only boot
        # partition and mounts at /boot.
        fileSystems."/boot".device = lib.mkForce "/dev/disk/by-partlabel/disk-unzen-sn770-ESP";
        fileSystems."/boot-secondary".enable = false;
        boot.loader.grub.mirroredBoots = lib.mkForce [
          {
            path = "/boot";
            devices = [ "nodev" ];
          }
        ];

        # Do not import the shared btrfs disk layer. All OS/data subvolumes
        # share the unencrypted pool. Only the small ESPs have fixed sizes.

        # Both 95 W limits completed the staged CPU + read-only SSD test.
        # No voltage offsets, temperature targets, or turbo override are set.
        services.undervolt = {
          enable = true;
          # Required by the upstream options. These encode the existing
          # 27983872 / 2440 us sysfs windows, rather than selecting new ones.
          p1 = {
            limit = 95;
            window = 28;
          };
          p2 = {
            limit = 95;
            window = 0.00244;
          };
        };
      };
  };
}

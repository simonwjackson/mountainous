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
        # With the enclosure attached, the media health read must name only
        # real mount points (a folder inside the pool fails every read).
        unzen-towada-health =
          let
            moved = self.nixosConfigurations.unzen.extendModules {
              modules = [ { mountainous.features.towada.enable = true; } ];
            };
            health = lib.findFirst (
              p: (p.name or "") == "media-storage-health"
            ) null moved.config.environment.systemPackages;
          in
          assert health != null;
          assert
            lib.hasInfix "bcachefs scrub" (
              moved.config.systemd.services."bcachefs-scrub-srv-lakes-towada".script or ""
            )
            || moved.config.systemd.services."bcachefs-scrub-srv-lakes-towada".serviceConfig ? ExecStart;
          assert moved.config.systemd.timers ? "bcachefs-scrub-srv-lakes-towada";
          assert builtins.elem "/" moved.config.services.bcachefs.autoScrub.fileSystems;
          assert lib.hasInfix " /srv/lakes/towada " (health.text + " ");
          assert !(lib.hasInfix "/srv/lakes/towada/media" health.text);
          pkgs.runCommand "unzen-towada-health" { } "touch $out";
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
      "media-jellyfin"
      "towada"
    ];

    module =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        towadaHere = config.mountainous.features.towada.enable;
        # Every Towada disk is a bcachefs member; no XFS disk remains.
        towadaMembers = {
          "00" = "7SGKDA3C";
          "01" = "VRJVWS3K";
          "02" = "VGH3KRAG";
          "03" = "VGH13XMG";
          "04" = "WD-CA081PBK";
        };
        towadaLegacy = { };
      in
      {
        imports = [
          inputs.disko.nixosModules.disko
          ../../disks/unzen.nix
        ];
        # The enclosure is attached to Unzen. The library is the local pool.
        mountainous.features.towada = {
          enable = lib.mkDefault true;
          # Chosen ahead; towada-convert formats the pool with it.
          uuid = "5b6c01f6-935b-4f22-9667-e16689d76dcb";
          # Replaceable data (media, games, firmware, Takeout) keeps one copy.
          # What cannot be downloaded again keeps two, on different disks.
          twoCopies = [
            "photos"
            "backups"
            "sdc1_backup.tar.gz"
            "code"
            "gaming/profiles"
            "gaming/profiles-backup-20251219.tar.gz"
            "books"
            "comics"
            "knowledge"
            "PLEASE-SORT-SOON"
          ];
          members = towadaMembers;
          legacy = towadaLegacy;
        };
        mountainous.features.media-runtime = lib.mkIf towadaHere {
          libraryLocalRoot = "/srv/lakes/towada/media";
          libraryLocalMountPoint = "/srv/lakes/towada";
          # The copy stores files with Unzen's media group.
          libraryMediaGid = 390;
        };
        mountainous.features.media-jellyfin.enable = towadaHere;
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

        # Storage failures reach the phone through the ntfy hub on Rakku.
        # The publish-only token lives in its own file (master + Unzen).
        sops.secrets.storage-alerts-token = {
          sopsFile = ../../secrets/notify/storage-unzen.yaml;
          mode = "0400";
        };
        mountainous.features.storage-alerts = {
          enable = true;
          profile = "unzen";
          notify = self.packages.${pkgs.stdenv.hostPlatform.system}.notify-sync;
          tokenFile = config.sops.secrets.storage-alerts-token.path;
          buttonTokenFile = config.sops.secrets.notify-button-token.path;
          units = [
            "media-storage-ready.service"
            "media-storage-health.service"
            "media-storage-failed.service"
            "media-library-mover@.service"
            "bcachefs-scrub-root.service"
          ]
          ++ (
            if towadaHere then
              [
                "towada-admission.service"
                "srv-lakes-towada.mount"
                "bcachefs-scrub-srv-lakes-towada.service"
                "jellyfin.service"
              ]
            else
              [ "net-mountainous-zao-media.mount" ]
          )
          ++ [
            "srv-media\\x2dlibrary\\x2dview-movies.mount"
            "srv-media\\x2dlibrary\\x2dview-tv.mount"
            "srv-range-media-movies.mount"
            "srv-range-media-tv.mount"
          ];
        };

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

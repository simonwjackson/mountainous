# Rehearse the Towada conversion on disposable virtual disks, never hardware:
# boot with the pool absent, format the two former parity disks, copy three
# read-only XFS disks with the media group remapped, verify irreplaceable files
# by SHA-256, then wipe and add each old disk to the pool.
{ pkgs, towadaModule }:
let
  # vdb..vdf stand in for the enclosure. Serial = old disk id.
  disks = {
    vdb = "02";
    vdc = "03";
    vdd = "00";
    vde = "01";
    vdf = "04";
  };
in
pkgs.testers.runNixOSTest {
  name = "towada-conversion";
  nodes.machine =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ towadaModule ];
      virtualisation.emptyDiskImages = [
        1024
        1024
        1024
        1024
        1024
      ];
      virtualisation.memorySize = 2048;
      # The test VM replaces fileSystems with its own set; add the module's.
      virtualisation.fileSystems = config.mountainous.features.towada.mounts;
      users.groups.media.gid = 390;
      users.groups.oldmedia.gid = 993;
      environment.systemPackages = [
        pkgs.xfsprogs
        pkgs.parted
      ];
      services.udev.extraRules = lib.concatStrings (
        lib.mapAttrsToList (kernel: id: ''
          KERNEL=="${kernel}", SYMLINK+="disk/by-id/fx-${id}"
          KERNEL=="${kernel}1", SYMLINK+="disk/by-id/fx-${id}-part1"
        '') disks
      );
      mountainous.features.towada = {
        enable = true;
        uuid = "0b7e9a52-6b1d-4c1e-9f0a-7a0c6b1e0001";
        idPrefix = "fx-";
        idSuffix = "";
        members = {
          "02" = "02";
          "03" = "03";
        };
        legacy = {
          "00" = "00";
          "01" = "01";
          "04" = "04";
        };
      };
    };
  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Old layout: XFS data disks 00/01/04 and parity disks 02/03.
    for kernel, disk in ${builtins.toJSON disks}.items():
        machine.succeed(f"parted -s /dev/{kernel} mklabel gpt mkpart data 1MiB 100%")
        machine.succeed(f"udevadm settle; mkfs.xfs -q -f /dev/{kernel}1")
    machine.succeed("udevadm trigger; udevadm settle")
    for disk in ["00", "01", "04", "02", "03"]:
        machine.succeed(f"mkdir -p /mnt/{disk}; mount /dev/disk/by-id/fx-{disk}-part1 /mnt/{disk}")
    machine.succeed(
        "mkdir -p /mnt/00/photos/library /mnt/01/media/movies /mnt/01/gaming/games /mnt/04/gaming/games",
        "printf photo > /mnt/00/photos/library/a.jpg",
        "printf movie > /mnt/01/media/movies/m.mkv",
        "printf winner > /mnt/01/gaming/games/g.rom; printf loser-longer > /mnt/04/gaming/games/g.rom",
        "touch -d '2020-01-01' /mnt/04/gaming/games/g.rom",
        "printf content > /mnt/01/snapraid.content; printf parity > /mnt/02/snapraid.0.parity",
        "chgrp -R 993 /mnt/00 /mnt/01 /mnt/04",
    )
    manifest = machine.succeed("cd /mnt/00 && sha256sum photos/library/a.jpg").strip()
    machine.succeed(f"printf '%s\\n' '{manifest}' > /root/manifest.sha256")
    machine.succeed("umount /mnt/00 /mnt/01 /mnt/04 /mnt/02 /mnt/03")

    with subtest("pool absent: boot finished, admission refuses, nothing mounts"):
        machine.fail("systemctl start towada-admission.service")
        machine.fail("systemctl start srv-lakes-towada.mount")
        machine.fail("mountpoint -q /srv/lakes/towada")
        failed = machine.succeed("systemctl --failed --no-legend --plain | cut -d' ' -f1").split()
        assert all("towada" in unit for unit in failed), failed

    with subtest("format refuses without the exact confirmation, then creates the pool"):
        machine.fail("towada-convert format 02 03 --confirm yes")
        machine.fail("towada-convert format 02 --confirm wipe-02")
        machine.succeed("towada-convert format 02 03 --confirm wipe-02-03")
        machine.fail("towada-convert format 02 03 --confirm wipe-02-03")
        machine.succeed("systemctl reset-failed; systemctl start srv-lakes-towada.mount")
        machine.succeed("mountpoint -q /srv/lakes/towada")
        assert machine.succeed("findmnt -no FSTYPE /srv/lakes/towada").strip() == "bcachefs"

    with subtest("copy order 04, 01, 00: read-only sources, group remapped, old winner kept"):
        machine.fail("towada-convert add 00 --confirm wipe-00")
        for disk in ["04", "01", "00"]:
            machine.succeed(f"towada-convert copy {disk}")
            assert "ro" in machine.succeed(f"findmnt -no OPTIONS /srv/shores/towada/{disk}").split(",")
        machine.succeed("test $(cat /srv/lakes/towada/gaming/games/g.rom) = winner")
        machine.succeed("test $(cat /srv/lakes/towada/media/movies/m.mkv) = movie")
        machine.fail("test -e /srv/lakes/towada/snapraid.content")
        assert machine.succeed("stat -c %g /srv/lakes/towada/photos/library/a.jpg").strip() == "390"

    with subtest("verify catches a wrong hash, then passes"):
        machine.succeed("sed 's/^./0/' /root/manifest.sha256 > /root/bad.sha256")
        machine.fail("towada-convert verify /root/bad.sha256")
        machine.fail("towada-convert add 00 --confirm wipe-00")
        machine.succeed("towada-convert verify /root/manifest.sha256")

    with subtest("add wipes one old disk at a time and keeps every file readable"):
        machine.fail("towada-convert add 00 --confirm wipe-01")
        for disk in ["00", "01", "04"]:
            machine.succeed(f"towada-convert add {disk} --confirm wipe-{disk}")
            machine.fail(f"towada-convert add {disk} --confirm wipe-{disk}")
            machine.succeed("test $(cat /srv/lakes/towada/photos/library/a.jpg) = photo")
        devices = machine.succeed("ls -d /sys/fs/bcachefs/*/dev-*").split()
        assert len(devices) == 5, devices
        fs = machine.succeed("ls -d /sys/fs/bcachefs/*-*").split()[0]
        for option in ["data_replicas", "metadata_replicas"]:
            assert machine.succeed(f"cat {fs}/options/{option}").strip() == "2"
        machine.succeed("bcachefs fs usage /srv/lakes/towada")
        labels = sorted(machine.succeed("cat /sys/fs/bcachefs/*-*/dev-*/label").split())
        assert labels == ["towada.00", "towada.01", "towada.02", "towada.03", "towada.04"], labels

    with subtest("the systemd mount finds all five members by UUID after the conversion"):
        machine.succeed("systemctl stop srv-lakes-towada.mount")
        machine.fail("mountpoint -q /srv/lakes/towada")
        machine.succeed("systemctl start srv-lakes-towada.mount")
        devices = machine.succeed("ls -d /sys/fs/bcachefs/*-*/dev-*").split()
        assert len(devices) == 5, devices
        machine.succeed("test $(cat /srv/lakes/towada/gaming/games/g.rom) = winner")
        machine.succeed("bcachefs scrub /srv/lakes/towada")
  '';
}

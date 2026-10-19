{
  pkgs,
  storagePkgs ? pkgs,
}:
pkgs.testers.runNixOSTest {
  name = "disk-array-safe-drain";
  node.pkgs = pkgs.lib.mkForce (pkgs.extend (_: _: {inherit (storagePkgs) mergerfs snapraid rsync;}));
  nodes.machine = {
    lib,
    pkgs,
    ...
  }: {
    imports = [../features/disk-array ../features/media ../features/media-tiering ../hosts/zao/nscd.nix ../hosts/zao/storage.nix];
    mountainous.features.media = {
      enable = true;
      root = "/srv/lakes/towada";
      storageUnit = "srv-lakes-towada.mount";
    };
    mountainous.features.media-tiering = {
      enable = true;
      role = "sink";
      peerHost = "client";
      nfs.clients = "*";
    };
    systemd.services.jellyfin = {
      wantedBy = ["multi-user.target"];
      serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
    };
    systemd.services.jellyfin-seed-bootstrap.serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/true";
    };
    systemd.timers.media-tiering-peer-mount.wantedBy = lib.mkForce [];
    networking.firewall.enable = false;
    virtualisation.fileSystems = lib.mkForce {};
    fileSystems."/" = {
      device = "/dev/vda";
      fsType = "ext4";
    };
    fileSystems."/nix/store" = {
      device = "nix-store";
      fsType = "9p";
      neededForBoot = true;
      options = ["trans=virtio" "version=9p2000.L" "msize=1048576" "cache=loose"];
    };
    virtualisation.emptyDiskImages = [512 512 512 512];
    virtualisation.memorySize = 1536;
    environment.systemPackages = with pkgs; [python3 xfsprogs parted util-linux rsync mergerfs dnsmasq];
    environment.etc."disk-array-tests/features/disk-array/mover.py".source = ../features/disk-array/mover.py;
    environment.etc."disk-array-tests/tests/test_disk_array_mover.py".source = ./test_disk_array_mover.py;
    services.udev.extraRules = ''
      KERNEL=="vdb1", SYMLINK+="fixture-data0-part1"
      KERNEL=="vdc1", SYMLINK+="fixture-data1-part1"
      KERNEL=="vdd1", SYMLINK+="fixture-parity-part1"
    '';
    mountainous.features.disk-array = {
      enable = true;
      pools.towada = {
        disks = [
          {
            id = "00";
            device = "/dev/fixture-data0";
            mountOptions = ["nofail" "x-systemd.device-timeout=2s"];
          }
          {
            id = "01";
            device = "/dev/fixture-data1";
            mountOptions = ["nofail" "x-systemd.device-timeout=2s"];
          }
          {
            id = "02";
            device = "/dev/fixture-parity";
            mountOptions = ["nofail" "x-systemd.device-timeout=2s"];
          }
        ];
        cache = {
          enable = true;
          device = "/dev/vde1";
          fsType = "xfs";
          fsRoot = "/";
          mover.olderThan = 0;
        };
        mergerfs.dataDisks = ["00" "01"];
        mergerfs.extraOptions = ["minfreespace=1M"];
        snapraid = {
          enable = true;
          dataDisks = ["00" "01"];
          parityDisks = ["02"];
          maxRemoved = 0;
          maxUpdated = 0;
        };
      };
    };
    fileSystems."/srv/cache/towada" = {
      device = "/dev/vde1";
      fsType = "xfs";
      options = ["nofail" "x-systemd.device-timeout=2s"];
    };
    # Disable timers only in the fixture. Tests invoke the actual generated CLI.
    systemd.timers.towada-cache-mover.wantedBy = lib.mkForce [];
    systemd.timers.towada-snapraid-sync.wantedBy = lib.mkForce [];
    systemd.timers.towada-snapraid-scrub.wantedBy = lib.mkForce [];
  };
  nodes.client = {pkgs, ...}: {
    environment.systemPackages = [pkgs.bindfs pkgs.nfs-utils];
    virtualisation.memorySize = 512;
    networking.firewall.enable = false;
  };
  testScript = builtins.readFile ./disk-array-vm.py;
}

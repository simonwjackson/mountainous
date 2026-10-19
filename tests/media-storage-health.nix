# Reproduce stale pinned bindfs source handles over real NFS, not injected errno.
{ pkgs, inputs }:
let
  applications =
    (import ../modules/media-applications.nix { inherit inputs; }).nixos.modules.media-applications;
  runtime = (import ../modules/media-runtime.nix { inherit inputs; }).nixos.modules.media-runtime;
in
pkgs.testers.runNixOSTest {
  name = "media-storage-health";
  nodes = {
    client =
      { config, lib, ... }:
      {
        imports = [
          applications
          runtime
        ];
        mountainous.features.media-applications = {
          enable = true;
          mediaGid = 390;
          library = "scryer";
          placement = lib.genAttrs [
            "scryer"
            "sonarr"
            "radarr"
            "prowlarr"
            "nzbget"
            "nzbfast"
            "transmission"
          ] (_: "client");
        };
        mountainous.features.media-runtime = {
          enable = true;
          libraryHost = "client";
          libraryServer = "server";
          libraryMover.enable = true;
        };
        virtualisation.fileSystems = lib.mkMerge [
          (import ../lib/media-storage-layout.nix {
            inherit lib;
            host = "client";
            placement = config.mountainous.features.media-applications.placement;
            libraryConsumer = true;
            libraryHost = "client";
            libraryServer = "server";
            tailDomain = "hummingbird-lake.ts.net";
            mediaGid = 390;
            libraryOwnerUid = 0;
            libraryMediaGid = 993;
            libraryUsers = {
              movies = 275;
              tv = 274;
            };
          })
          { "/net/mountainous/zao/media".options = [ "actimeo=0" ]; }
        ];
        # Disable attribute caching only in the fixture: invalidation is immediate
        # and the test needs no sleeps or retries to manufacture a stale handle.
        systemd.targets.tailscale-online = { };
        networking.hosts."192.168.1.1" = [ "client.hummingbird-lake.ts.net" ];
        networking.hosts."192.168.1.2" = [ "server.hummingbird-lake.ts.net" ];
        networking.firewall.enable = false;
        # Use the real Scryer and Transmission unit dependency/admission contracts,
        # but never initialize application databases or connect to a torrent peer.
        services.scryer.writablePaths = lib.mkForce [ ];
        systemd.services.scryer = {
          unitConfig.ConditionPathExists = lib.mkForce [ ];
          unitConfig.ConditionFileNotEmpty = lib.mkForce [ ];
          preStart = lib.mkForce "";
          serviceConfig = {
            ExecStartPre = lib.mkOverride 40 [ ];
            LoadCredential = lib.mkForce [ ];
            Type = lib.mkForce "exec";
            ExecStart = lib.mkForce "${pkgs.coreutils}/bin/sleep infinity";
            ExecStartPost = lib.mkForce [ ];
          };
        };
        systemd.services.transmission = {
          unitConfig.ConditionPathExists = lib.mkForce [ ];
          unitConfig.ConditionFileNotEmpty = lib.mkForce [ ];
          preStart = lib.mkForce "";
          requires = lib.mkForce [ "media-storage-ready.service" ];
          bindsTo = lib.mkForce [ "media-storage-ready.service" ];
          serviceConfig = {
            ExecStartPre = lib.mkOverride 40 [ ];
            LoadCredential = lib.mkForce [ ];
            Type = lib.mkForce "exec";
            ExecStart = lib.mkForce "${pkgs.coreutils}/bin/sleep infinity";
            NetworkNamespacePath = lib.mkForce "";
            BindReadOnlyPaths = lib.mkForce [
              "/nix/store"
              "/etc"
            ];
          };
        };
        # Admit a deliberate startup below, not during boot before the exporter.
        systemd.services.scryer.wantedBy = lib.mkForce [ ];
        systemd.services.transmission.wantedBy = lib.mkForce [ ];
        environment.systemPackages = [ pkgs.python3 ];
        virtualisation.memorySize = 1024;
      };
    server = {
      networking.firewall.enable = false;
      services.nfs.server = {
        enable = true;
        exports = "/srv/library *(rw,fsid=0,no_subtree_check,no_root_squash)";
      };
      systemd.tmpfiles.rules = [
        "d /srv/library/movies 0777 root root -"
        "d /srv/library/tv 0777 root root -"
      ];
      systemd.services.nfs-server.after = [ "systemd-tmpfiles-setup.service" ];
    };
  };
  testScript = ''
    import shlex
    start_all()
    server.wait_for_unit("nfs-server.service")
    client.wait_for_unit("multi-user.target")
    client.succeed("systemctl start media-storage-ready.service scryer.service transmission.service")
    client.succeed("systemctl is-active --quiet scryer.service transmission.service")
    client.succeed("media-storage-health")
    client.succeed("printf retained-state > /var/lib/media-migration/fixture-hold; chmod 600 /var/lib/media-migration/fixture-hold")
    hold = client.succeed("sha256sum /var/lib/media-migration/fixture-hold")
    # The old inode disappears while bindfs retains its cwd/file handle. A
    # pathname lookup of the fresh NFS directory still succeeds.
    server.succeed("rmdir /srv/library/movies; mkdir -m 777 /srv/library/movies")
    client.succeed("stat /net/mountainous/zao/media/movies /srv/range/media/movies")
    client.succeed("python3 -c " + shlex.quote("import os, errno\ntry: os.stat('/srv/media-library-view/movies')\nexcept OSError as e: assert e.errno == errno.ESTALE, e\nelse: raise AssertionError('expected actual NFS ESTALE')"))
    # Reproduce the original misleading oneshot status before health runs.
    client.succeed("systemctl is-active --quiet media-storage-ready.service")
    client.fail("media-storage-health")
    client.fail("systemctl start media-storage-health.service")
    client.wait_until_succeeds("test -f /run/media-storage-blocked")
    for unit in ("scryer", "transmission", "media-storage-ready"):
        client.wait_until_fails("systemctl is-active --quiet " + unit + ".service")
    client.fail("systemctl is-active --quiet media-storage-health.timer")
    captured = client.succeed("cat /run/media-storage-failure.units")
    for unit in ("scryer.service", "transmission.service"):
        assert any("Id=" + unit in block and "ActiveState=active" in block for block in captured.split("\n\n")), captured
    assert client.succeed("sha256sum /var/lib/media-migration/fixture-hold") == hold
    client.fail("systemctl start media-storage-ready.service")
    # Bounded recovery in reverse dependency order. Never lazy/force unmount.
    for path in ("/srv/range/media/movies", "/srv/range/media/tv", "/srv/media-library-view/movies", "/srv/media-library-view/tv"):
        unit = client.succeed("systemd-escape --path --suffix=mount " + path).strip()
        client.succeed("systemctl stop " + shlex.quote(unit))
        client.fail("mountpoint -q " + path)
    for path in ("/srv/media-library-view/movies", "/srv/media-library-view/tv", "/srv/range/media/movies", "/srv/range/media/tv"):
        unit = client.succeed("systemd-escape --path --suffix=mount " + path).strip()
        client.succeed("systemctl start " + shlex.quote(unit))
    client.succeed("media-storage-health")
    client.fail("systemctl start media-storage-ready.service")
    # A refused admission schedules OnFailure asynchronously. Drain that job
    # before removing its latch; do not race it or add a timing sleep.
    client.succeed("systemctl start media-storage-failed.service; systemctl stop media-storage-ready.service")
    client.succeed("rm /run/media-storage-blocked; systemctl start media-storage-ready.service")
    client.succeed("media-storage-health")
    # Rebuilding the views must not resume either application or mover timers.
    for unit in ("scryer.service", "transmission.service", "media-library-mover-nightly.timer"):
        client.fail("systemctl is-active --quiet " + unit)
    client.succeed("systemctl start scryer.service transmission.service")
    client.succeed("systemctl is-active --quiet scryer.service transmission.service")
  '';
}

# Real NFS mounts, missing-state gates and WireGuard routes in disposable VMs.
{ pkgs, inputs }:
let
  applications =
    (import ../modules/media-applications.nix { inherit inputs; }).nixos.modules.media-applications;
  runtime = (import ../modules/media-runtime.nix { }).nixos.modules.media-runtime;
  assignments = {
    sonarr = "arr";
    radarr = "arr";
    prowlarr = "unzen";
    nzbget = "unzen";
    transmission = "unzen";
  };
  common =
    { config, lib, ... }:
    {
      imports = [
        applications
        runtime
      ];
      # QEMU replaces normal host filesystems. Give its adapter the same layout.
      virtualisation.fileSystems = import ../lib/media-storage-layout.nix {
        inherit lib;
        host = config.networking.hostName;
        placement = assignments;
        inherit (config.mountainous.features.media-runtime)
          libraryHost
          libraryServer
          tailDomain
          libraryOwnerUid
          libraryMediaGid
          ;
        mediaGid = config.users.groups.media.gid;
        libraryUsers = {
          movies = config.ids.uids.radarr;
          tv = config.ids.uids.sonarr;
        };
      };
      mountainous.features.media-applications = {
        enable = true;
        mediaGid = 390;
        placement = assignments;
      };
      mountainous.features.media-runtime.enable = true;
      networking.firewall.enable = false;
      networking.hosts = {
        "192.168.1.1" = [ "arr.hummingbird-lake.ts.net" ];
        "192.168.1.2" = [ "unzen.hummingbird-lake.ts.net" ];
        "100.90.0.2" = [
          "tv.hummingbird-lake.ts.net"
          "movies.hummingbird-lake.ts.net"
          "indexers.hummingbird-lake.ts.net"
          "usenet.hummingbird-lake.ts.net"
          "torrents.hummingbird-lake.ts.net"
        ];
        "192.168.1.3" = [ "zao.hummingbird-lake.ts.net" ];
      };
      virtualisation.memorySize = 1024;
      # Sparse test disks must satisfy the real mergerfs 10G reserve.
      virtualisation.diskSize = 20480;
      virtualisation.cores = 1;
      environment.systemPackages = [
        pkgs.curl
        pkgs.wireguard-tools
        pkgs.python3
      ];
    };
in
pkgs.testers.runNixOSTest {
  name = "portable-media-runtime";
  nodes = {
    unzen =
      { ... }:
      {
        imports = [ common ];
        systemd.services.media-vpn.environment = {
          VPN_NS_CHECK_URL = "http://10.99.0.1:8080/exit";
          VPN_NS_HEALTH_URL = "http://10.99.0.1:8080/exit";
        };
      };
    arr =
      { config, ... }:
      {
        imports = [ common ];
        # A real process consumes the production Sonarr dependency contract.
        # It avoids initializing disposable ARR application state just to test stop ordering.
        systemd.services.media-library-consumer-fixture = {
          inherit (config.systemd.services.sonarr) requires after bindsTo;
          serviceConfig = {
            User = "sonarr";
            ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
          };
        };
      };
    zao =
      { ... }:
      {
        users.groups.media.gid = 993;
        networking.firewall.enable = false;
        services.nfs.server = {
          enable = true;
          exports = "/srv/fixture-library *(rw,fsid=0,no_subtree_check,all_squash,anonuid=0,anongid=993)";
        };
        systemd.tmpfiles.rules = [
          "d /srv/fixture-library 2775 root media -"
          "d /srv/fixture-library/movies 2775 root media -"
          "d /srv/fixture-library/tv 2775 root media -"
        ];
        systemd.services.nfs-server.after = [ "systemd-tmpfiles-setup.service" ];
        virtualisation.memorySize = 512;
        environment.systemPackages = [
          pkgs.wireguard-tools
          pkgs.python3
        ];
      };
  };
  testScript = ''
    import shlex
    start_all()
    with subtest("boot has no ordering cycles or discarded dependency jobs"):
        for machine in (arr, unzen, zao):
            machine.wait_for_unit("multi-user.target")
            machine.fail("journalctl -b --no-pager | grep -E 'Found ordering cycle|deleted to break ordering cycle'")
    zao.wait_for_unit("nfs-server.service")
    unzen.wait_for_unit("nfs-server.service")
    arr.wait_for_unit("multi-user.target")

    with subtest("missing state cannot start a setup wizard"):
        for machine, services in ((unzen, ["nzbget", "transmission", "prowlarr"]), (arr, ["sonarr", "radarr"])):
            for service in services:
                machine.succeed("systemctl start " + service + ".service")
                machine.fail("systemctl is-active --quiet " + service + ".service")
        arr.fail("test -e /var/lib/sonarr/.config/NzbDrone/sonarr.db")
        unzen.fail("test -e /var/lib/nzbget/nzbget.conf")

    with subtest("ARR sees remote completed files without exposing partial work"):
        unzen.succeed("touch /srv/basin/downloads/usenet/completed/finished")
        unzen.succeed("touch /srv/basin/downloads/usenet/intermediate/private-work")
        arr.succeed("systemctl start media-storage-ready.service")
        arr.succeed("test -f /srv/basin/downloads/usenet/completed/finished")
        arr.fail("test -e /srv/basin/downloads/usenet/completed/private-work")
        arr.succeed("runuser -u sonarr -- python3 ${./media-storage-probe.py} /srv/range/media/tv/remote-library-write")
        arr.succeed("runuser -u sonarr -- python3 ${./media-storage-probe.py} /net/mountainous/zao/media/tv/long-term-library-write")
        zao.succeed("install -d -o root -g media -m 2775 /srv/fixture-library/tv/existing-show/season")
        arr.succeed("runuser -u sonarr -- python3 ${./media-storage-probe.py} /srv/range/media/tv/existing-show/season/new-episode")
        arr.succeed("test $(stat -c %u:%g /srv/media-library-view/tv/existing-show/season) = 274:390")
        zao.succeed("test $(stat -c %u:%g /srv/fixture-library/tv/existing-show/season) = 0:993")
        # New imports still use staging when the existing directory is on Zao.
        unzen.succeed("test $(stat -c %u:%g /srv/basin/media/tv/existing-show/season/new-episode) = 274:390")
        zao.fail("test -e /srv/fixture-library/tv/existing-show/season/new-episode")
        arr.succeed("runuser -u sonarr -- python3 ${./media-storage-probe.py} /srv/media-library-view/tv/existing-show/season/view-write")
        zao.succeed("test $(stat -c %u:%g /srv/fixture-library/tv/existing-show/season/view-write) = 0:993")
        zao.succeed("install -d -o root -g media -m 2775 /srv/fixture-library/movies/existing-movie")
        arr.succeed("runuser -u radarr -- python3 ${./media-storage-probe.py} /srv/range/media/movies/existing-movie/new-movie")
        arr.succeed("test $(stat -c %u:%g /srv/media-library-view/movies/existing-movie) = 275:390")
        zao.succeed("test $(stat -c %u:%g /srv/fixture-library/movies/existing-movie) = 0:993")
        arr.fail("runuser -u sonarr -- chown sonarr /srv/media-library-view/tv/existing-show/season/view-write")
        arr.fail("runuser -u sonarr -- chgrp media /srv/media-library-view/tv/existing-show/season/view-write")
        zao.succeed("test $(stat -c %u:%g /srv/fixture-library/tv/existing-show/season/view-write) = 0:993")
        # The view does not relabel or rewrite existing owner-only media.
        zao.succeed("install -o root -g media -m 600 ${pkgs.writeText "old-episode-fixture" "preserved-library-bytes"} /srv/fixture-library/tv/existing-show/season/old-episode")
        original = zao.succeed("sha256sum /srv/fixture-library/tv/existing-show/season/old-episode")
        arr.succeed("runuser -u sonarr -- cmp ${pkgs.writeText "old-episode-fixture" "preserved-library-bytes"} /srv/range/media/tv/existing-show/season/old-episode")
        zao.succeed("test $(stat -c %u:%g:%a /srv/fixture-library/tv/existing-show/season/old-episode) = 0:993:600")
        assert zao.succeed("sha256sum /srv/fixture-library/tv/existing-show/season/old-episode") == original
        zao.succeed("test -f /srv/fixture-library/tv/long-term-library-write")
        unzen.succeed("test -f /srv/basin/media/tv/remote-library-write")

    with subtest("mixed existing library owners permit timestamp-preserving pooled writes without relabeling"):
        zao.succeed("install -d -o 991 -g media -m 2775 /srv/fixture-library/tv/legacy-writer-owned/season")
        zao.succeed("install -o 991 -g media -m 664 ${pkgs.writeText "old-episode-fixture" "preserved-library-bytes"} /srv/fixture-library/tv/legacy-writer-owned/season/existing-episode")
        arr.succeed("runuser -u sonarr -- python3 ${./media-storage-probe.py} /srv/range/media/tv/legacy-writer-owned/season/existing-episode")
        zao.succeed("test $(stat -c %u:%g:%a /srv/fixture-library/tv/legacy-writer-owned/season/existing-episode) = 991:993:664")
        zao.succeed("test $(stat -c %u:%g:%a /srv/fixture-library/tv/legacy-writer-owned/season) = 991:993:2775")
        zao.succeed("install -d -o 991 -g media -m 2775 /srv/fixture-library/movies/legacy-writer-owned")
        zao.succeed("install -o 991 -g media -m 664 ${pkgs.writeText "old-episode-fixture" "preserved-library-bytes"} /srv/fixture-library/movies/legacy-writer-owned/existing-movie")
        arr.succeed("runuser -u radarr -- python3 ${./media-storage-probe.py} /srv/range/media/movies/legacy-writer-owned/existing-movie")
        zao.succeed("test $(stat -c %u:%g:%a /srv/fixture-library/movies/legacy-writer-owned/existing-movie) = 991:993:664")
        zao.succeed("test $(stat -c %u:%g:%a /srv/fixture-library/movies/legacy-writer-owned) = 991:993:2775")

    with subtest("mapped view loss stops a consumer with the production ARR dependencies"):
        arr.succeed("systemctl start media-library-consumer-fixture.service")
        arr.wait_for_unit("media-library-consumer-fixture.service")
        view_unit = arr.succeed("systemd-escape --path --suffix=mount /srv/media-library-view/tv").strip()
        arr.succeed("systemctl stop " + shlex.quote(view_unit))
        arr.wait_until_fails("systemctl is-active --quiet media-library-consumer-fixture.service")
        arr.fail("systemctl is-active --quiet media-storage-ready.service")
        arr.fail("mountpoint -q /srv/range/media/tv")
        arr.succeed("systemctl start media-storage-ready.service")
        arr.succeed("runuser -u sonarr -- python3 ${./media-storage-probe.py} /srv/range/media/tv/existing-show/season/after-view-restart")

    with subtest("required storage loss stops ARR instead of writing into an empty mountpoint"):
        arr.succeed("systemctl stop media-storage-ready.service")
        arr.succeed("umount /srv/basin/downloads/usenet/completed")
        unzen.succeed("systemctl stop nfs-server.service")
        arr.fail("timeout 15 systemctl start media-storage-ready.service")
        unzen.succeed("systemctl start nfs-server.service")

    with subtest("WireGuard is the only default route and tunnel loss has no host-route fallback"):
        for machine in (unzen, zao):
            machine.succeed("install -d -m 700 /run/wg-fixture")
            machine.succeed("wg genkey > /run/wg-fixture/private")
        server_key = zao.succeed("wg pubkey < /run/wg-fixture/private").strip()
        client_key = unzen.succeed("wg pubkey < /run/wg-fixture/private").strip()
        zao.succeed("ip link add wg-fixture type wireguard")
        zao.succeed("wg set wg-fixture private-key /run/wg-fixture/private listen-port 51820 peer " + client_key + " allowed-ips 10.99.0.2/32")
        zao.succeed("ip addr add 10.99.0.1/24 dev wg-fixture")
        zao.succeed("ip link set wg-fixture up")
        zao.succeed("install -d /srv/http-fixture")
        zao.succeed("printf 198.51.100.10 > /srv/http-fixture/exit")
        zao.succeed("systemd-run --unit=wg-http-fixture python3 -m http.server 8080 --bind 10.99.0.1 --directory /srv/http-fixture")
        unzen.succeed("install -d -m 700 /var/lib/media-migration/credentials")
        unzen.succeed("printf '[Interface]\\nAddress = 10.99.0.2/32\\nDNS = 10.99.0.1\\nPrivateKey = ' > /var/lib/media-migration/credentials/wireguard.conf")
        unzen.succeed("cat /run/wg-fixture/private >> /var/lib/media-migration/credentials/wireguard.conf")
        unzen.succeed("printf '\\n[Peer]\\nPublicKey = " + server_key + "\\nEndpoint = 192.168.1.3:51820\\nAllowedIPs = 0.0.0.0/0\\n' >> /var/lib/media-migration/credentials/wireguard.conf")
        unzen.succeed("chmod 600 /var/lib/media-migration/credentials/wireguard.conf")
        unzen.succeed("touch /var/lib/media-migration/ready/vpn")
        unzen.succeed("systemctl start media-vpn.service")
        unzen.succeed("ip netns exec vpn curl --fail --max-time 5 http://10.99.0.1:8080/exit")
        unzen.succeed("ip netns exec vpn ip route show default | grep 'dev wg-vpn'")
        unzen.succeed("ip netns exec vpn ip link del wg-vpn")
        unzen.fail("ip netns exec vpn curl --fail --max-time 3 http://10.99.0.1:8080/exit")
        unzen.fail("ip netns exec vpn ip route show default | grep veth")
  '';
}

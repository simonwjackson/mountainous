# Real NFS mounts, missing-state gates and WireGuard routes in disposable VMs.
{ pkgs, inputs }:
let
  applications =
    (import ../modules/media-applications.nix { inherit inputs; }).nixos.modules.media-applications;
  runtime = (import ../modules/media-runtime.nix { inherit inputs; }).nixos.modules.media-runtime;
  identities =
    (import ../modules/media-identities.nix { inherit inputs; }).nixos.modules.media-identities;
  assignments = {
    sonarr = "arr";
    radarr = "arr";
    prowlarr = "unzen";
    nzbget = "unzen";
    nzbfast = "unzen";
    transmission = "unzen";
  };
  common =
    { config, lib, ... }:
    {
      imports = [
        applications
        runtime
        identities
      ];
      # QEMU replaces normal host filesystems. Give its adapter the same layout.
      virtualisation.fileSystems = import ../lib/media-storage-layout.nix {
        inherit lib;
        host = config.networking.hostName;
        placement = config.mountainous.features.media-applications.placement;
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
        usenet = "both";
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
        "192.168.1.4" = [ "zcolocated.hummingbird-lake.ts.net" ];
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
      { lib, ... }:
      {
        imports = [ common ];
        mountainous.features.media-runtime.libraryMover = {
          enable = true;
          minAgeMinutes = 0;
        };
        # Keep Prowlarr's real namespace/readiness dependencies, but use a
        # sleeping fixture instead of constructing application state here.
        systemd.services.prowlarr = {
          preStart = lib.mkForce "";
          serviceConfig.ExecStart = lib.mkForce "${pkgs.coreutils}/bin/sleep infinity";
        };
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
    zcolocated =
      { config, lib, ... }:
      {
        imports = [ common ];
        mountainous.features.media-applications.placement = lib.mkForce (
          lib.genAttrs (builtins.attrNames assignments) (_: "zcolocated")
        );
        mountainous.features.media-runtime = {
          libraryHost = "zcolocated";
          libraryMover = {
            enable = true;
            minAgeMinutes = 0;
          };
        };
        systemd.services.media-local-staging-consumer-fixture = {
          inherit (config.systemd.services.radarr) requires after bindsTo;
          serviceConfig = {
            User = "radarr";
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
        for machine in (arr, unzen, zao, zcolocated):
            machine.wait_for_unit("multi-user.target")
            machine.fail("journalctl -b --no-pager | grep -E 'Found ordering cycle|deleted to break ordering cycle'")
    zao.wait_for_unit("nfs-server.service")
    unzen.wait_for_unit("nfs-server.service")
    arr.wait_for_unit("multi-user.target")

    with subtest("missing state cannot start a setup wizard"):
        for machine, services in ((unzen, ["nzbget", "nzbfast", "transmission", "prowlarr"]), (arr, ["sonarr", "radarr"])):
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

    with subtest("colocated ARR uses ordinary local staging and real library mount fences"):
        zcolocated.succeed("touch /srv/basin/downloads/usenet/completed/local-finished")
        zcolocated.succeed("systemctl start media-storage-ready.service media-local-staging-consumer-fixture.service")
        zcolocated.wait_for_unit("media-local-staging-consumer-fixture.service")
        zcolocated.fail("mountpoint -q /srv/basin/downloads/usenet/completed")
        zcolocated.fail("mountpoint -q /srv/basin/downloads/torrents/completed")
        zcolocated.succeed("runuser -u radarr -- test -r /srv/basin/downloads/usenet/completed/local-finished")
        dependencies = zcolocated.succeed("systemctl show media-storage-ready.service -p BindsTo --value").split()
        assert "srv-basin-downloads-usenet-completed.mount" not in dependencies
        assert "srv-basin-downloads-torrents-completed.mount" not in dependencies
        assert "net-mountainous-zao-media.mount" in dependencies
        view_unit = zcolocated.succeed("systemd-escape --path --suffix=mount /srv/media-library-view/movies").strip()
        zcolocated.succeed("systemctl stop " + shlex.quote(view_unit))
        zcolocated.wait_until_fails("systemctl is-active --quiet media-local-staging-consumer-fixture.service")
        zcolocated.fail("systemctl is-active --quiet media-storage-ready.service")
        zcolocated.succeed("systemctl start media-storage-ready.service media-local-staging-consumer-fixture.service")
        zcolocated.wait_for_unit("media-local-staging-consumer-fixture.service")

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

    with subtest("actual mover publishes through mapped NFS on library hosts with and without local ARR"):
        import json
        zao.succeed("systemd-run --unit=library-refresh-fixture python3 ${./media-library-refresh-server.py} /run/library-refresh-received /run/library-refresh-response-status")
        zao.wait_for_unit("library-refresh-fixture.service")
        for machine in (unzen, zcolocated):
            machine.succeed("install -d -m 700 /var/lib/media-migration/credentials")
            settings = json.dumps({"url": "http://192.168.1.3:8097", "api_key": "fixture-only-token"})
            machine.succeed("printf %s " + shlex.quote(settings) + " > /var/lib/media-migration/credentials/library-refresh.json")
            machine.succeed("chmod 600 /var/lib/media-migration/credentials/library-refresh.json")
            machine.succeed("systemctl start media-storage-ready.service")
            machine.succeed("systemctl start media-library-mover@nightly.service")
            machine.fail("test -e /var/lib/media-migration/ready/library-mover")
            title = "mover-" + machine.name
            machine.succeed("install -d -o 274 -g media -m 2775 /srv/basin/media/tv/" + title)
            machine.succeed("install -o 274 -g media -m 664 ${pkgs.writeText "verified-mover-fixture" "verified-media-bytes"} /srv/basin/media/tv/" + title + "/episode.mkv")
            machine.succeed("touch /var/lib/media-migration/ready/library-mover")
            result, output = machine.execute("systemctl start media-library-mover@nightly.service")
            if result:
                print(machine.succeed("journalctl --no-pager -u media-library-mover@nightly.service"))
                raise Exception("Actual mapped-library handoff failed: " + output)
            machine.fail("test -e /srv/basin/media/tv/" + title + "/episode.mkv")
            zao.succeed("cmp ${pkgs.writeText "verified-mover-fixture" "verified-media-bytes"} /srv/fixture-library/tv/" + title + "/episode.mkv")
            zao.succeed("test $(stat -c %u:%g:%a /srv/fixture-library/tv/" + title + "/episode.mkv) = 0:993:664")
            machine.succeed("test -d /srv/basin/media/tv && test -d /srv/basin/media/movies")
            machine.fail("systemctl is-active --quiet media-library-mover-nightly.timer")
        assert int(zao.succeed("cat /run/library-refresh-received").strip()) == 2

    with subtest("actual refresh failure keeps a durable receipt and retry succeeds without another import"):
        zao.succeed("echo 503 > /run/library-refresh-response-status")
        unzen.succeed("install -d -o 274 -g media -m 2775 /srv/basin/media/tv/refresh-retry")
        unzen.succeed("install -o 274 -g media -m 664 ${pkgs.writeText "verified-mover-fixture" "verified-media-bytes"} /srv/basin/media/tv/refresh-retry/episode.mkv")
        unzen.fail("systemctl start media-library-mover@nightly.service")
        unzen.fail("test -e /srv/basin/media/tv/refresh-retry/episode.mkv")
        zao.succeed("cmp ${pkgs.writeText "verified-mover-fixture" "verified-media-bytes"} /srv/fixture-library/tv/refresh-retry/episode.mkv")
        unzen.succeed("test $(stat -c %u:%g:%a /var/lib/media-migration/library-handoff/refresh-pending) = 0:0:600")
        unzen.succeed("test -d /srv/basin/media/tv && test -d /srv/basin/media/movies")
        zao.succeed("echo 204 > /run/library-refresh-response-status")
        unzen.succeed("systemctl start media-library-mover@nightly.service")
        unzen.fail("test -e /var/lib/media-migration/library-handoff/refresh-pending")
        zao.succeed("test $(cat /run/library-refresh-received) = 3")
        unzen.succeed("test -d /srv/basin/media/tv && test -d /srv/basin/media/movies")

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
        with subtest("NZBFAST requires both gates, validates servers and starts held in the real VPN sandbox"):
            import json
            unzen.succeed("touch /var/lib/media-migration/ready/nzbfast")
            unzen.succeed("systemctl start nzbfast.service")
            unzen.fail("systemctl is-active --quiet nzbfast.service")
            # Exercise the actual provisioning CLI with fixture-only credentials.
            source = "Server1.Host=news.example.invalid\nServer1.Username=fixture-user\nServer1.Password=fixture-password\n"
            unzen.succeed("printf %s " + shlex.quote(source) + " > /run/nzbget-fixture.conf")
            checked = unzen.succeed("python3 ${../scripts/media-nzbfast-provision.py} --source /run/nzbget-fixture.conf --check")
            provisioned = unzen.succeed("python3 ${../scripts/media-nzbfast-provision.py} --source /run/nzbget-fixture.conf")
            for output in (checked, provisioned):
                assert all(secret not in output for secret in ("news.example.invalid", "fixture-user", "fixture-password")), output
            unzen.fail("python3 ${../scripts/media-nzbfast-provision.py} --source /run/nzbget-fixture.conf")
            unzen.succeed("test $(stat -c %a:%U:%G /var/lib/nzbfast/config.json) = 600:nzbfast:media")
            unzen.succeed("rm /var/lib/media-migration/ready/nzbfast")
            unzen.succeed("systemctl start nzbfast.service")
            unzen.fail("systemctl is-active --quiet nzbfast.service")
            unzen.succeed("touch /var/lib/media-migration/ready/nzbfast")
            original_config = unzen.succeed("cat /var/lib/nzbfast/config.json")
            unzen.succeed("runuser -u nzbfast -- sh -c " + shlex.quote("printf %s " + shlex.quote(json.dumps({"servers": []})) + " > /var/lib/nzbfast/config.json"))
            unzen.fail("systemctl start nzbfast.service")
            unzen.succeed("systemctl stop nzbfast.service")
            unzen.fail("test -e /var/lib/nzbfast/settings.json")
            unzen.succeed("runuser -u nzbfast -- sh -c " + shlex.quote("printf %s " + shlex.quote(original_config) + " > /var/lib/nzbfast/config.json"))
            # Use the pinned daemon's real service path. Saved scheduler text
            # replays after restore_pause; raw lists must fail closed as well.
            resume_schedule = [{"days": "all", "time": "00:00", "action": "resume"}]
            for policy in ({"schedule": json.dumps(resume_schedule)}, {"schedule": resume_schedule}, {"pause_until_unix": 1}, {"pause_until_unix": 4102444800}):
                held_settings = json.dumps({"apikey": "fixture-schedule-key", "paused": True, "offline": True, **policy})
                unzen.succeed("runuser -u nzbfast -- sh -c " + shlex.quote("umask 077; printf %s " + shlex.quote(held_settings) + " > /var/lib/nzbfast/settings.json"))
                unzen.succeed("systemctl reset-failed nzbfast.service")
                unzen.fail("systemctl start nzbfast.service")
                unzen.succeed("systemctl stop nzbfast.service")
                unzen.fail("systemctl is-active --quiet nzbfast.service")
                assert unzen.succeed("cat /var/lib/nzbfast/settings.json") == held_settings
                unzen.fail("test -d /var/lib/nzbfast/.spool")
            empty_settings = json.dumps({"apikey": "fixture-schedule-key", "schedule": "[]"})
            unzen.succeed("runuser -u nzbfast -- sh -c " + shlex.quote("printf %s " + shlex.quote(empty_settings) + " > /var/lib/nzbfast/settings.json"))
            unzen.succeed("systemctl reset-failed nzbfast.service")
            unzen.succeed("systemctl start nzbfast.service")
            unzen.wait_for_unit("nzbfast.service")
            unzen.succeed("test $(id -u nzbfast) = 391")
            unzen.wait_until_succeeds("curl --fail --silent http://10.200.200.2:6790/api?mode=version >/dev/null")
            key = json.loads(unzen.succeed("cat /var/lib/nzbfast/settings.json"))["apikey"]
            def fast_queue():
                return json.loads(unzen.succeed("curl --fail --silent 'http://10.200.200.2:6790/api?mode=queue&output=json&apikey=" + key + "'"))["queue"]
            queue = fast_queue()
            assert queue["paused"] and queue["offline"], queue
            assert json.loads(unzen.succeed("cat /var/lib/nzbfast/settings.json"))["schedule"] == "[]"
            audit_selection = json.loads(unzen.succeed("python3 ${../scripts/media-vpn-leak-audit.py} --list-services"))
            assert audit_selection == {"vpnUnits": ["nzbfast.service", "nzbget.service", "transmission.service", "prowlarr.service"], "dnsUnits": ["nzbfast.service", "nzbget.service"]}
            live_config = json.loads(unzen.succeed("curl --fail --silent 'http://10.200.200.2:6790/api?mode=get_config&output=json&apikey=" + key + "'"))["config"]
            live = live_config["nzbfast"]
            for forced_off in ("auto_rename", "spot_enabled", "index_enabled", "identity_lookup", "update_checks", "delete_to_trash"):
                assert live[forced_off] is False, (forced_off, live[forced_off])
            assert live["out_umask"] == "002", live["out_umask"]
            categories = {category["name"]: category["dir"] for category in live_config["categories"]}
            assert categories["Series"] == "Series" and categories["Movies"] == "Movies", categories
            before = json.loads(unzen.succeed("cat /var/lib/nzbfast/settings.json"))
            unzen.succeed("systemctl restart nzbfast.service")
            unzen.wait_for_unit("nzbfast.service")
            unzen.wait_until_succeeds("curl --fail --silent http://10.200.200.2:6790/api?mode=version >/dev/null")
            after = json.loads(unzen.succeed("cat /var/lib/nzbfast/settings.json"))
            assert before == after, (before, after)
            assert fast_queue()["paused"] and fast_queue()["offline"]
            unzen.succeed("test -d /var/lib/nzbfast/.spool")
            unzen.succeed("test $(stat -c %a:%U:%G /srv/basin/downloads/usenet/nzbfast) = 2775:root:media")
            unzen.succeed("runuser -u nzbget -- touch /srv/basin/downloads/usenet/nzbfast/Series/group-writable")
            pid_fast = unzen.succeed("systemctl show nzbfast.service -p MainPID --value").strip()
            unzen.fail("nsenter -t " + pid_fast + " -m test -S /run/nscd/socket")
            assert unzen.succeed("stat -Lc %i /proc/" + pid_fast + "/ns/net").strip() == unzen.succeed("stat -Lc %i /run/netns/vpn").strip()
        unzen.fail("systemctl is-active --quiet prowlarr.service")
        # Satisfy the retained file-presence conditions for the sleeping fixture.
        # The real state validator remains covered by the preservation VM.
        unzen.succeed("install -d /var/lib/prowlarr")
        unzen.succeed("printf fixture > /var/lib/prowlarr/prowlarr.db")
        unzen.succeed("printf fixture > /var/lib/prowlarr/config.xml")
        unzen.succeed("touch /var/lib/media-migration/ready/prowlarr")
        unzen.succeed("systemctl restart media-vpn.service")
        unzen.wait_for_unit("prowlarr.service")
        original_pid = unzen.succeed("systemctl show prowlarr.service -p MainPID --value").strip()
        unzen.succeed("systemctl stop media-vpn.service")
        unzen.wait_until_fails("systemctl is-active --quiet prowlarr.service")
        unzen.wait_until_fails("systemctl is-active --quiet nzbfast.service")
        unzen.succeed("systemctl start media-vpn.service")
        unzen.wait_for_unit("prowlarr.service")
        unzen.wait_for_unit("nzbfast.service")
        assert unzen.succeed("systemctl show prowlarr.service -p MainPID --value").strip() != original_pid
        # The host name-service cache resolves names outside the tunnel. A
        # VPN consumer must not reach it, yet must still resolve users.
        pid = unzen.succeed("systemctl show prowlarr.service -p MainPID --value").strip()
        unzen.succeed("test -S /run/nscd/socket")
        unzen.fail("nsenter -t " + pid + " -m test -S /run/nscd/socket")
        nss = unzen.succeed("tr '\\0' '\\n' < /proc/" + pid + "/environ | sed -n 's/^LD_LIBRARY_PATH=//p'").strip()
        unzen.succeed("test -e " + nss + "/libnss_systemd.so.2")
        unzen.succeed("nsenter -t " + pid + " -m -n env LD_LIBRARY_PATH=" + nss + " getent passwd root")
        unzen.succeed("nsenter -t " + pid + " -m -n env LD_LIBRARY_PATH=" + nss + " getent hosts usenet.hummingbird-lake.ts.net")
        unzen.succeed("ip netns exec vpn ip link del wg-vpn")
        unzen.fail("ip netns exec vpn curl --fail --max-time 3 http://10.99.0.1:8080/exit")
        unzen.fail("ip netns exec vpn ip route show default | grep veth")
  '';
}

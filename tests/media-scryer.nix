# Real packaged Scryer: offline startup, provisioning and sandbox permissions.
{ pkgs, inputs }:
let
  applications =
    (import ../modules/media-applications.nix { inherit inputs; }).nixos.modules.media-applications;
  identities =
    (import ../modules/media-identities.nix { inherit inputs; }).nixos.modules.media-identities;
  runtime = (import ../modules/media-runtime.nix { inherit inputs; }).nixos.modules.media-runtime;
  tools = (import ../modules/media-scryer.nix { inherit inputs; }).nixos.modules.media-scryer;
  node = mode: { lib, ... }: {
    imports = [
      applications
      identities
      runtime
      tools
    ];
    mountainous.features.media-applications = {
      enable = true;
      mediaGid = 390;
      library = mode;
      placement =
        lib.genAttrs [ "sonarr" "radarr" "prowlarr" "nzbget" "nzbfast" "transmission" ] (_: "elsewhere")
        // {
          scryer = mode;
        };
    };
    # The VM performs several recovery windows and a 43-title fixture in one
    # minute. Keep production rate limits unchanged, but do not throttle tests.
    services.scryer.environment = {
      SCRYER_LOGIN_RATE_LIMIT_ATTEMPTS = "100";
      SCRYER_API_RATE_LIMIT_REQUESTS = "3000";
      SCRYER_MUTATION_RATE_LIMIT_REQUESTS = "3000";
    };
    mountainous.features.media-runtime = {
      enable = true;
      libraryHost = "elsewhere";
    };
    # Use real mount units at every production dependency, without remote NFS.
    virtualisation.fileSystems =
      lib.mapAttrs
        (
          _: source:
          lib.mkForce {
            device = source;
            fsType = "none";
            options = [
              "bind"
              "_netdev"
              "noauto"
              "x-systemd.requires=systemd-tmpfiles-setup.service"
            ];
          }
        )
        {
          "/net/mountainous/zao/media" = "/srv/basin/media";
          "/srv/media-library-view/tv" = "/srv/basin/media/tv";
          "/srv/media-library-view/movies" = "/srv/basin/media/movies";
          "/srv/range/media/tv" = "/srv/basin/media/tv";
          "/srv/range/media/movies" = "/srv/basin/media/movies";
          "/srv/basin/downloads/usenet/completed" = "/srv/fixture-completed-usenet";
          "/srv/basin/downloads/torrents/completed" = "/srv/fixture-completed-torrents";
        };
    systemd.tmpfiles.rules = map (path: "d ${path} 2775 root media -") [
      "/srv/range/media/tv"
      "/srv/range/media/movies"
      "/srv/basin/media/tv"
      "/srv/basin/media/movies"
      "/srv/media-library-view/tv"
      "/srv/media-library-view/movies"
      "/net/mountainous/zao/media/tv"
      "/net/mountainous/zao/media/movies"
      "/srv/basin/downloads/usenet/nzbfast"
      "/srv/basin/downloads/torrents/completed"
      "/srv/media-access"
      "/srv/fixture-completed-usenet"
      "/srv/fixture-completed-torrents"
    ];
    environment.systemPackages = [
      pkgs.curl
      pkgs.python3
      pkgs.util-linux
    ];
    virtualisation.memorySize = 2048;
    virtualisation.cores = 2;
  };
  moverFixtures = pkgs.runCommand "scryer-mover-fixtures" { } ''
    mkdir -p "$out/modules" "$out/scripts"
    cp ${../modules/media-library-mover.py} "$out/modules/media-library-mover.py"
    cp ${../modules/media-library-cleanup.py} "$out/modules/media-library-cleanup.py"
    cp ${../scripts/test-media-library-mover.py} "$out/scripts/test-media-library-mover.py"
    cp ${../scripts/media-scryer-common.py} "$out/media-scryer-common.py"
    cp ${./media-scryer-api-probe.py} "$out/media-scryer-api-probe.py"
    cp ${./media-scryer-review-probe.py} "$out/media-scryer-review-probe.py"
    cp ${../scripts/media-scryer-provision.py} "$out/media-scryer-provision.py"
    cp ${../scripts/media-scryer-import.py} "$out/media-scryer-import.py"
    cp ${../scripts/media-scryer-parity.py} "$out/media-scryer-parity.py"
  '';
in
pkgs.testers.runNixOSTest {
  name = "media-scryer-held-trial";
  nodes = {
    both = node "both";
    scryer = node "scryer";
  };
  testScript = ''
    start_all()
    for machine in (both, scryer):
        machine.wait_for_unit("multi-user.target")
        machine.fail("systemctl is-active scryer.service")
        machine.succeed("media-scryer-provision --open-gate")
        bootstrap_hash = machine.succeed("sha256sum /var/lib/media-migration/credentials/scryer-admin-password")
        machine.succeed("systemctl start scryer.service")
        machine.wait_for_unit("scryer.service")
        machine.succeed("curl -fsS http://127.0.0.1:8080/health/ready")
        phase = "password-before-server" if machine == both else "password-after-server"
        machine.succeed("python3 ${moverFixtures}/media-scryer-review-probe.py " + phase)
        replacement_hash = machine.succeed("sha256sum /var/lib/media-migration/credentials/scryer-admin-password.pending").split()[0]
        machine.succeed("media-scryer-provision")
        assert machine.succeed("sha256sum /var/lib/media-migration/credentials/scryer-admin-password").split()[0] == replacement_hash
        assert machine.succeed("sha256sum /var/lib/media-migration/credentials/scryer-admin-password") != bootstrap_hash
        identity_before = machine.succeed("sha256sum /var/lib/media-migration/credentials/scryer.json")
        machine.succeed("python3 ${moverFixtures}/media-scryer-review-probe.py password-after-publish")
        machine.succeed("media-scryer-provision --plugins")
        machine.succeed("test ! -e /var/lib/media-migration/credentials/scryer-admin-password.pending")
        assert machine.succeed("sha256sum /var/lib/media-migration/credentials/scryer.json") == identity_before
        machine.succeed("python3 ${moverFixtures}/media-scryer-api-probe.py")
        machine.succeed("test $(stat -c %a /var/lib/media-migration/credentials/scryer.json) = 600")
        machine.succeed("test $(stat -c %u /var/lib/scryer) = 392")
        machine.succeed("systemctl restart scryer.service")
        machine.wait_for_unit("scryer.service")
        machine.succeed("python3 ${moverFixtures}/media-scryer-api-probe.py")
    with subtest("catalog-only metadata adds fill all 43 IDs without directories or download jobs"):
        both.succeed("media-library-snapshot create /root/catalog-before.json")
        both.succeed("python3 ${moverFixtures}/media-scryer-review-probe.py catalog-only", timeout=240)
        both.succeed("media-library-snapshot create /root/catalog-after.json; media-library-snapshot compare /root/catalog-before.json /root/catalog-after.json")
        both.succeed("media-scryer-indexer-audit")
    with subtest("upgrades stay off until an explicit verified match-source transition"):
        both.succeed("python3 ${moverFixtures}/media-scryer-review-probe.py source-profiles")
        both.succeed("media-scryer-provision --upgrades match-source --source-archive /var/lib/media-migration/review-archive")
        both.succeed("python3 ${moverFixtures}/media-scryer-review-probe.py verify-match-source")
        both.succeed("media-scryer-provision")
        both.succeed("python3 ${moverFixtures}/media-scryer-api-probe.py")
    with subtest("the packaged snapshot command preserves dot files and permits new entries"):
        both.succeed("printf fixture > /srv/range/media/tv/.snapshot-fixture; media-library-snapshot create /root/before.json")
        both.succeed("touch /srv/range/media/tv/new-fixture; media-library-snapshot create /root/after.json")
        both.succeed("media-library-snapshot compare /root/before.json /root/after.json")
        both.succeed("rm /srv/range/media/tv/.snapshot-fixture; media-library-snapshot create /root/missing.json")
        both.fail("media-library-snapshot compare /root/before.json /root/missing.json")
    with subtest("both: the real service mount namespace refuses all library and completed writes"):
        both.fail("nsenter -t $(systemctl show -p MainPID --value scryer) -m -- runuser -u scryer -- touch /srv/range/media/tv/probe")
        both.fail("nsenter -t $(systemctl show -p MainPID --value scryer) -m -- runuser -u scryer -- touch /srv/basin/media/tv/probe")
        both.fail("nsenter -t $(systemctl show -p MainPID --value scryer) -m -- runuser -u scryer -- touch /srv/basin/downloads/torrents/completed/probe")
    with subtest("both: late writable host mounts cannot bypass the read-only library"):
        both.succeed("mkdir -p /srv/late-writable /srv/range/media/tv/late /srv/media-access/x; chgrp media /srv/late-writable; chmod 2775 /srv/late-writable")
        both.succeed("mount --bind /srv/late-writable /srv/range/media/tv/late; mount --bind /srv/late-writable /srv/media-access/x")
        both.succeed("runuser -u scryer -- touch /srv/range/media/tv/late/host-probe")
        both.fail("nsenter -t $(systemctl show -p MainPID --value scryer) -m -- runuser -u scryer -- touch /srv/range/media/tv/late/namespace-probe")
        both.fail("nsenter -t $(systemctl show -p MainPID --value scryer) -m -- runuser -u scryer -- touch /srv/media-access/x/export-probe")
        both.succeed("umount /srv/range/media/tv/late; umount /srv/media-access/x")
    with subtest("library mount restart rebuilds the Scryer namespace after the mount"):
        for machine in (both, scryer):
            before = machine.succeed("systemctl show -p InvocationID --value scryer.service")
            machine.succeed("systemctl restart srv-range-media-tv.mount")
            machine.wait_for_unit("scryer.service")
            assert machine.succeed("systemctl show -p InvocationID --value scryer.service") != before
            machine.succeed("nsenter -t $(systemctl show -p MainPID --value scryer) -m -- mountpoint -q /srv/range/media/tv")
    with subtest("scryer: the real service mount namespace permits import and remove-completed"):
        scryer.succeed("nsenter -t $(systemctl show -p MainPID --value scryer) -m -- runuser -u scryer -- sh -c 'touch /srv/range/media/tv/probe /srv/basin/media/tv/probe /srv/basin/downloads/usenet/nzbfast/probe /srv/basin/downloads/torrents/completed/probe; rm /srv/basin/downloads/torrents/completed/probe'")
    with subtest("copy fallback has completion-source, library-publication and remove-completed access"):
        scryer.succeed("nsenter -t $(systemctl show -p MainPID --value scryer) -m -- runuser -u scryer -- sh -ec 'printf copy-fixture > /srv/basin/downloads/usenet/nzbfast/copy-source; if ln /srv/basin/downloads/usenet/nzbfast/copy-source /srv/range/media/tv/copy-target; then exit 1; fi; cp /srv/basin/downloads/usenet/nzbfast/copy-source /srv/range/media/tv/copy-target; cmp /srv/basin/downloads/usenet/nzbfast/copy-source /srv/range/media/tv/copy-target; rm /srv/basin/downloads/usenet/nzbfast/copy-source; test -s /srv/range/media/tv/copy-target'")
    with subtest("mover accepts numeric Scryer ownership without remapping the destination"):
        scryer.succeed("python3 ${moverFixtures}/scripts/test-media-library-mover.py")
  '';
}

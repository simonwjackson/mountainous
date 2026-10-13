# Real packaged Scryer: offline startup, provisioning and sandbox permissions.
{ pkgs, inputs }:
let
  applications =
    (import ../modules/media-applications.nix { inherit inputs; }).nixos.modules.media-applications;
  identities =
    (import ../modules/media-identities.nix { inherit inputs; }).nixos.modules.media-identities;
  tools = (import ../modules/media-scryer.nix { inherit inputs; }).nixos.modules.media-scryer;
  node = mode: { lib, ... }: {
    imports = [
      applications
      identities
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
    systemd.services.scryer = {
      requires = [ "media-storage-ready.service" ];
      after = [ "media-storage-ready.service" ];
    };
    systemd.services.media-storage-ready = {
      after = [ "systemd-tmpfiles-setup.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = "test -d /srv/range/media/tv";
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
        machine.succeed("media-scryer-provision")
        assert machine.succeed("sha256sum /var/lib/media-migration/credentials/scryer-admin-password") != bootstrap_hash
        identity_before = machine.succeed("sha256sum /var/lib/media-migration/credentials/scryer.json")
        machine.succeed("media-scryer-provision --plugins")
        assert machine.succeed("sha256sum /var/lib/media-migration/credentials/scryer.json") == identity_before
        machine.succeed("python3 ${moverFixtures}/media-scryer-api-probe.py")
        machine.succeed("test $(stat -c %a /var/lib/media-migration/credentials/scryer.json) = 600")
        machine.succeed("test $(stat -c %u /var/lib/scryer) = 392")
        machine.succeed("systemctl restart scryer.service")
        machine.wait_for_unit("scryer.service")
        machine.succeed("python3 ${moverFixtures}/media-scryer-api-probe.py")
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
    with subtest("scryer: the real service mount namespace permits import and remove-completed"):
        scryer.succeed("nsenter -t $(systemctl show -p MainPID --value scryer) -m -- runuser -u scryer -- sh -c 'touch /srv/range/media/tv/probe /srv/basin/media/tv/probe /srv/basin/downloads/usenet/nzbfast/probe /srv/basin/downloads/torrents/completed/probe; rm /srv/basin/downloads/torrents/completed/probe'")
    with subtest("mover accepts numeric Scryer ownership without remapping the destination"):
        scryer.succeed("python3 ${moverFixtures}/scripts/test-media-library-mover.py")
  '';
}

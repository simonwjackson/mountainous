# Exercise the production unit's filesystem, identity, slice and stop policy.
# This does not replace live registration, job cancellation or fork routing.
{ pkgs, ... }:
{
  name = "github-actions-isolation";

  nodes.machine =
    { config, pkgs, ... }:
    let
      runner = config.systemd.services.github-runner-forgerie;
      loopback = pkgs.writeText "ci-loopback.py" ''
        import http.server
        import threading
        import urllib.request
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"ci-loopback")
            def log_message(self, *args):
                pass
        server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever)
        thread.start()
        try:
            with urllib.request.urlopen("http://127.0.0.1:" + str(server.server_port), timeout=5) as response:
                assert response.read() == b"ci-loopback"
        finally:
            server.shutdown()
            thread.join()
            server.server_close()
      '';
      probe = pkgs.writeShellScript "ci-isolation-probe" ''
        set -euo pipefail
        [[ "$(node --version)" == v24.* ]]
        [[ "$(command -v node)" == /nix/store/* ]]
        [[ "$(findmnt -n -o FSTYPE -T /tmp)" != tmpfs ]]
        [[ "$(findmnt -n -o FSTYPE -T /var/tmp)" != tmpfs ]]
        touch "$TMPDIR/writable" /tmp/job-local
        if cat /run/secrets/github-actions-forgerie-app-key; then exit 1; fi
        if cat /var/lib/github-runner/forgerie/.current-token; then exit 1; fi
        if nix --extra-experimental-features nix-command store ping --store daemon; then exit 1; fi
        [[ "$(</proc/self/cgroup)" == *github-actions.slice* ]]
        python3 ${loopback}
        touch /srv/github-actions/work/forgerie/probe-ready
        exec sleep infinity
      '';
    in
    {
      imports = [ (import ../modules/github-actions.nix).nixos.modules.base ];
      mountainous.features.github-actions.enable = true;
      services.github-runners.forgerie.githubApp = {
        id = 123456;
        login = "forgerie";
        privateKeyFile = "/run/secrets/github-actions-forgerie-app-key";
      };
      # Invalid test data, not a credential. Registration must fail closed.
      systemd.tmpfiles.rules = [
        "d /run/secrets 0755 root root -"
        "f /run/secrets/github-actions-forgerie-app-key 0400 root root - invalid-test-key"
      ];
      # Prevent any test traffic from reaching GitHub even on an API regression.
      networking.hosts."127.0.0.1" = [ "api.github.com" ];
      virtualisation.memorySize = 2048;
      virtualisation.cores = 2;

      systemd.services.ci-isolation-probe = {
        environment = builtins.removeAttrs runner.environment [ "PATH" ];
        inherit (runner) path;
        # Reuse the fully merged production policy. Replace only the external
        # GitHub runner command/auth boundary with a deterministic workload.
        serviceConfig = runner.serviceConfig // {
          Type = "simple";
          ExecStartPre = [ (builtins.head runner.serviceConfig.ExecStartPre) ];
          ExecStart = "${probe}";
          ExecStopPost = [ ];
          Restart = "no";
          RestartForceExitStatus = [ ];
          TimeoutStopSec = "5s";
        };
      };
    };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_until_succeeds("systemctl is-failed github-runner-forgerie.service")
    machine.succeed("journalctl -u github-runner-forgerie.service | grep -F 'Runner registration refused'")
    machine.succeed("nix --extra-experimental-features nix-command store ping --store daemon")
    # World-readable test data proves namespace hiding, not only Unix modes.
    machine.succeed("chmod 0644 /run/secrets/github-actions-forgerie-app-key")
    machine.succeed("echo invalid-test-token > /var/lib/github-runner/forgerie/.current-token; chmod 0644 /var/lib/github-runner/forgerie/.current-token")
    machine.succeed("ln -s /run/current-system /nix/var/nix/gcroots/ci-retained-test")
    machine.succeed("systemctl start ci-isolation-probe.service")
    machine.wait_until_succeeds("test -f /srv/github-actions/work/forgerie/probe-ready")
    machine.fail("test -e /tmp/job-local")
    machine.succeed("test -f /srv/github-actions/tmp/forgerie/job-local")
    assert machine.succeed("systemctl show --property=MemoryMax --value github-actions.slice").strip() == "17179869184"
    assert machine.succeed("systemctl show --property=CPUQuotaPerSecUSec --value github-actions.slice").strip() == "4s"
    machine.succeed("systemctl stop ci-isolation-probe.service")
    machine.fail("pgrep -u github-runner-forgerie")
    machine.succeed("touch /srv/github-actions/tmp/forgerie/stale; rm /srv/github-actions/work/forgerie/probe-ready")
    machine.succeed("systemctl start ci-isolation-probe.service")
    machine.wait_until_succeeds("test -f /srv/github-actions/work/forgerie/probe-ready")
    machine.fail("test -e /srv/github-actions/tmp/forgerie/stale")
    machine.succeed("test -L /nix/var/nix/gcroots/ci-retained-test")
    machine.succeed("systemctl stop ci-isolation-probe.service")
  '';
}

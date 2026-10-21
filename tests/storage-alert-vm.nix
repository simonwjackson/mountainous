# Real ntfy with deny-all auth and a write-only storage-alerts user, the real
# notify CLI, and the real alert module on a client with a failing storage unit.
# All tokens and the hash here are VM-only fixtures, not fleet secrets.
{
  pkgs,
  notify,
  alertModule,
}:
let
  # bcrypt of "fixture-only-password"; every fixture user shares it.
  hash = "$2b$10$RA9/xgrcLGfuGc1/ubI5B.A73gvz8ctg7nDMdVJT.nReChegZaMvy";
  alertToken = "tk_alertsfixture0000000000000000";
  readerToken = "tk_readerfixture0000000000000000";
  buttonToken = "tk_buttonfixture0000000000000000";
  probe = pkgs.writeText "fixture-probe.sh" ''
    if [ -e /run/fixture-bad ]; then
      printf 'warn\tcache filesystem 82%% used\nbad\tfixture-storage.service failed\n'
    else
      printf 'ok\tall checks passed\n'
    fi
    printf 'complete\t%s\n' "$(date +%s)"
  '';
in
pkgs.testers.runNixOSTest {
  name = "storage-alert";
  nodes.hub = {
    networking.firewall.allowedTCPPorts = [ 2586 ];
    environment.etc."ntfy-auth.env".text = ''
      NTFY_AUTH_USERS=storage-alerts:${hash}:user,reader:${hash}:user,button:${hash}:user
      NTFY_AUTH_ACCESS=storage-alerts:notify:wo,storage-alerts:notify-ctl:deny,reader:notify:rw,button:notify:deny,button:notify-ctl:wo
      NTFY_AUTH_TOKENS=storage-alerts:${alertToken}:alerts,reader:${readerToken}:reader,button:${buttonToken}:button
    '';
    services.ntfy-sh = {
      enable = true;
      environmentFile = "/etc/ntfy-auth.env";
      settings = {
        base-url = "http://hub:2586";
        listen-http = ":2586";
        cache-file = "/var/lib/ntfy-sh/cache.db";
        auth-file = "/var/lib/ntfy-sh/auth.db";
        auth-default-access = "deny-all";
        cache-batch-size = 0;
        cache-batch-timeout = "0s";
        visitor-request-limit-exempt-hosts = "0.0.0.0/0";
      };
    };
  };
  nodes.client =
    { pkgs, ... }:
    {
      imports = [ alertModule ];
      environment.systemPackages = [ pkgs.curl ];
      environment.etc."alert-token".text = alertToken;
      environment.etc."button-token".text = buttonToken;
      mountainous.features.storage-alerts = {
        enable = true;
        profile = "fixture";
        inherit notify probe;
        url = "http://hub:2586";
        tokenFile = "/etc/alert-token";
        buttonTokenFile = "/etc/button-token";
        units = [ "fixture-storage.service" ];
      };
      # Stand-in for a storage unit: fails on demand, carries the OnFailure hook.
      systemd.services.fixture-storage.serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/false";
      };
    };
  testScript = ''
    import json

    def messages(token):
        out = client.succeed(
            f"curl -sf -H 'Authorization: Bearer {token}' 'http://hub:2586/notify/json?poll=1&since=all'"
        )
        return [json.loads(line) for line in out.splitlines() if line.strip()]

    def bodies():
        return [m.get("title", "") + " | " + m.get("message", "") for m in messages("${readerToken}")]

    def state():
        return json.loads(client.succeed("cat /var/lib/storage-alerts/state.json"))

    start_all()
    hub.wait_for_unit("ntfy-sh.service")
    hub.wait_for_open_port(2586)
    client.wait_for_unit("multi-user.target")

    with subtest("write-only token cannot read the topic"):
        code = client.succeed(
            "curl -s -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer ${alertToken}' "
            "'http://hub:2586/notify/json?poll=1'"
        ).strip()
        assert code in ("401", "403"), code

    with subtest("a failed storage unit triggers one alert through OnFailure"):
        client.succeed("touch /run/fixture-bad")
        client.fail("systemctl start fixture-storage.service")
        client.wait_until_succeeds("journalctl -u storage-alert.service | grep -q 'probe complete; 1 bad'", timeout=60)
        hub_bodies = bodies()
        assert sum("fixture-storage.service failed" in b for b in hub_bodies) == 1, hub_bodies
        assert not any("82" in b for b in hub_bodies), "warn findings must not alert"
        assert len(state()["alerts"]) == 1

    with subtest("an unchanged finding is not sent again"):
        before = len(messages("${readerToken}"))
        client.succeed("systemctl start storage-alert.service")
        assert len(messages("${readerToken}")) == before

    with subtest("recovery sends once and clears the alert"):
        client.succeed("rm /run/fixture-bad")
        client.succeed("systemctl start storage-alert.service")
        assert state()["alerts"] == {}
        assert sum("storage recovered" in b for b in bodies()) == 1
        client.fail("journalctl -u storage-alert.service | grep -q 'clear failed'")

    with subtest("hub down: publish fails, state keeps the finding for retry, storage unaffected"):
        hub.succeed("systemctl stop ntfy-sh.service")
        client.succeed("touch /run/fixture-bad")
        client.fail("systemctl start storage-alert.service")
        assert state()["alerts"] == {}
        # The failing storage unit still finishes at once, independent of the alert path.
        client.succeed("rc=0; timeout 10 systemctl start fixture-storage.service || rc=$?; test $rc -ne 0 && test $rc -ne 124")
        client.succeed("systemctl show -p ActiveState --value fixture-storage.service | grep -q failed")
        hub.succeed("systemctl start ntfy-sh.service")
        hub.wait_for_open_port(2586)
        client.wait_until_succeeds("systemctl start storage-alert.service", timeout=60)
        assert len(state()["alerts"]) == 1

    with subtest("no token appears in argv or the journal"):
        client.fail("journalctl -b | grep -q '${alertToken}'")
        client.fail("journalctl -b | grep -q '${buttonToken}'")
  '';
}

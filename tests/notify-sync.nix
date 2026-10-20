{ pkgs, package }:
let
  python = pkgs.python3.withPackages (ps: [ ps.dbus-fast ]);
in
pkgs.testers.runNixOSTest {
  name = "notify-sync";
  nodes.machine = { ... }: {
    services.dbus.enable = true;
    users.users.simon = {
      isNormalUser = true;
      uid = 1000;
      linger = true;
    };
    environment.systemPackages = [
      package
      pkgs.libnotify
      python
    ];
    environment.variables.NOTIFY_URL = "http://127.0.0.1:2586";
    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "http://127.0.0.1:2586";
        listen-http = "127.0.0.1:2586";
        cache-file = "/var/lib/ntfy-sh/cache.db";
        cache-duration = "720h";
        cache-batch-size = 0;
        cache-batch-timeout = "0s";
        visitor-request-limit-exempt-hosts = "127.0.0.1";
      };
    };
    environment.etc."notify-mcp-token".text = "VM-test-only-bearer-token-not-a-fleet-secret";
    systemd.services.notify-hub = {
      wantedBy = [ "multi-user.target" ];
      after = [ "ntfy-sh.service" ];
      serviceConfig.ExecStart = "${package}/bin/notify-hub --ntfy http://127.0.0.1:2586 --public-url http://127.0.0.1:2586 --mcp-token-file /etc/notify-mcp-token";
    };
    systemd.user.services.notifyd = {
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "dbus";
        BusName = "org.freedesktop.Notifications";
        ExecStart = "${package}/bin/notifyd --ntfy http://127.0.0.1:2586 --public-url http://127.0.0.1:2586 --host vm";
      };
    };
  };
  testScript = ''
    machine.wait_for_unit("ntfy-sh.service")
    machine.wait_for_unit("notify-hub.service")
    machine.wait_for_unit("user@1000.service")
    machine.wait_until_succeeds("test -S /run/user/1000/notify-sync/ui.sock")
    print(machine.succeed("su -s /bin/sh simon -c 'export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus NOTIFY_URL=http://127.0.0.1:2586; ${python}/bin/python ${./notify-sync-session.py}'"))
  '';
}

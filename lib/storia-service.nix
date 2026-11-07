{ pkgs }:
{
  serverArgs = [
    "--data-dir"
    "/var/lib/storia/data"
    "--config-dir"
    "/var/lib/storia/config"
  ];
  secrets = {
    storia-cliproxy-key = "config/cliproxy-key";
    storia-jev-key = "config/jev-key";
  };
  environment = {
    STORIA_CLIPROXY_URL = "https://ai.hummingbird-lake.ts.net";
    STORIA_JEV_URL = "https://ai.hummingbird-lake.ts.net/v1/systemone";
  };
  smokeCommand = "${pkgs.curl}/bin/curl -fsS --max-time 3 http://127.0.0.1:4390/healthz >/dev/null";
  checkCommand = ''
    test "$("$APP_PACKAGE/bin/storia-server" --version)" = 'storia-server 0.1.0'
  '';
}

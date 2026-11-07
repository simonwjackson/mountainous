# Preserve Knowledge's Pi model configuration without sharing an operator home.
{ pkgs, inputs }:
(import ./pi-service-runtime.nix {
  inherit pkgs inputs;
  name = "knowledge";
})
// {
  serverArgs = [
    "--data-dir"
    "/var/lib/knowledge/data"
    "--origin"
    "https://knowledge.hummingbird-lake.ts.net"
  ];
  smokeCommand = "${pkgs.curl}/bin/curl -fsS --max-time 3 http://127.0.0.1:4381/healthz >/dev/null";
  checkCommand = ''
    test "$("$APP_PACKAGE/bin/knowledge-server" --version)" = "knowledge-server $APP_VERSION"
    "$APP_PACKAGE/bin/knowledge-tsnet" --help 2>&1 | grep -q expected-fqdn
  '';
}

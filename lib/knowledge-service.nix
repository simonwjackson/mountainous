# Preserve Knowledge's Pi model configuration without sharing an operator home.
{ pkgs, inputs }:
let
  provider = pkgs.runCommand "knowledge-pi-cliproxyapi-provider" { } ''
    mkdir -p "$out"
    cp -r ${inputs.pi-cliproxyapi-provider}/. "$out/"
  '';
  settings = pkgs.writeText "knowledge-pi-settings.json" (
    builtins.toJSON {
      defaultProvider = "cliproxyapi";
      defaultModel = "claude-opus-5-5";
      packages = [ (toString provider) ];
    }
  );
in
{
  serverArgs = [
    "--data-dir"
    "/var/lib/knowledge/data"
    "--origin"
    "https://knowledge.hummingbird-lake.ts.net"
  ];
  secrets.knowledge-pi-cliproxyapi = ".pi/agent/cliproxyapi.json";
  readOnlyBinds = [ "${settings}:/var/lib/knowledge/.pi/agent/settings.json" ];
  smokeCommand = "${pkgs.curl}/bin/curl -fsS --max-time 3 http://127.0.0.1:4381/healthz >/dev/null";
  checkCommand = ''
    test "$("$APP_PACKAGE/bin/knowledge-server" --version)" = 'knowledge-server 0.1.0'
    "$APP_PACKAGE/bin/knowledge-tsnet" --help 2>&1 | grep -q expected-fqdn
  '';
}
